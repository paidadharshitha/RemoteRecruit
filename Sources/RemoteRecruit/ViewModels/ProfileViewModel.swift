// ProfileViewModel.swift
// RemoteRecruit

import Foundation
import Combine
import PDFKit

// MARK: - Upload Pipeline Step

/// Represents the current step in the resume processing pipeline.
public enum ResumePipelineStep: Equatable {
    case idle
    case uploading
    case extracting
    case parsing
    case saving
    case preview(ParsedResume)
    case done
    case failed(String)

    /// A short display string for the UI status indicator.
    public var displayName: String {
        switch self {
        case .idle:     return "Ready"
        case .uploading: return "Uploading resume…"
        case .extracting: return "Extracting text…"
        case .parsing: return "Analyzing with AI…"
        case .saving: return "Updating profile…"
        case .preview:   return "Review extracted data"
        case .done: return "Profile updated"
        case .failed: return "Failed"
        }
    }

    /// Whether the pipeline is currently active.
    public var isActive: Bool {
        switch self {
        case .uploading, .extracting, .parsing, .saving:
            return true
        default:
            return false
        }
    }
}

// MARK: - Parsed Resume (deduplicated from ResumeParseService)

/// Structured output from resume parsing used to autofill a UserProfile.
public struct ParsedResume: Codable, Equatable, Sendable {
    public let name: String
    public let email: String
    public let skills: [String]
    public let experience: String
    public let phone: String
    public let domain: String
    public let portfolioLink: String
    public let projects: [Project]
    public let workExperience: [WorkExperience]

    public init(
        name: String = "",
        email: String = "",
        skills: [String] = [],
        experience: String = "",
        phone: String = "",
        domain: String = "",
        portfolioLink: String = "",
        projects: [Project] = [],
        workExperience: [WorkExperience] = []
    ) {
        self.name = name
        self.email = email
        self.skills = skills
        self.experience = experience
        self.phone = phone
        self.domain = domain
        self.portfolioLink = portfolioLink
        self.projects = projects
        self.workExperience = workExperience
    }

    // Custom decoder with defaults so missing JSON keys don't crash decoding.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? container.decode(String.self, forKey: .name)) ?? ""
        self.email = (try? container.decode(String.self, forKey: .email)) ?? ""
        self.skills = (try? container.decode([String].self, forKey: .skills)) ?? []
        self.experience = (try? container.decode(String.self, forKey: .experience)) ?? ""
        self.phone = (try? container.decode(String.self, forKey: .phone)) ?? ""
        self.domain = (try? container.decode(String.self, forKey: .domain)) ?? ""
        self.portfolioLink = (try? container.decode(String.self, forKey: .portfolioLink)) ?? ""
        self.projects = (try? container.decode([Project].self, forKey: .projects)) ?? []
        self.workExperience = (try? container.decode([WorkExperience].self, forKey: .workExperience)) ?? []
    }
}

// MARK: - Resume Parsing State

/// Tracks the resume parsing flow state for the UI.
public enum ResumeParsingState: Equatable {
    case idle
    case parsing
    case preview(ParsedResume)
    case saving
    case done
    case error(String)

    public var isLoading: Bool {
        switch self {
        case .parsing, .saving: return true
        default: return false
        }
    }
}

// MARK: - Save Status

/// Lightweight feedback state for optimistic UI saves.
public enum OptimisticSaveStatus: Equatable {
    case idle
    case syncing
    case saved
    case failed
}

// MARK: - Profile ViewModel

/// Orchestrates the full resume pipeline: Upload → Extract → Parse → Preview → Save.
/// Provides `@Published` step state for a Task-based UI indicator and a
/// `ResumeParsingState` for the two-step preview-then-confirm flow.
@MainActor
public final class ProfileViewModel: ObservableObject {

    // MARK: - Published State

    /// Current step in the resume processing pipeline.
    @Published private(set) public var pipelineStep: ResumePipelineStep = .idle

    /// The user's Firestore profile, loaded on first appear.
    @Published private(set) public var profile: UserProfile?

    /// Whether the profile is being fetched.
    @Published private(set) public var isFetchingProfile = false

    /// Error message if profile fetch fails.
    @Published private(set) public var profileErrorMessage: String?

    /// Whether a document picker is shown.
    @Published public var showDocumentPicker = false

    /// Current state of the resume parsing flow (idle → parsing → preview → saving → done).
    @Published private(set) public var parsingState: ResumeParsingState = .idle

    /// The most recently parsed resume — published so ProfileView can auto-fill fields.
    @Published private(set) public var parsedResume: ParsedResume?

    /// The extracted skills from the last successful parse (for job recommendations).
    @Published private(set) public var extractedSkills: [String] = []

    /// Feedback status for optimistic academic details save.
    @Published public var academicSaveStatus: OptimisticSaveStatus = .idle

    /// Feedback status for optimistic preferences save.
    @Published public var preferencesSaveStatus: OptimisticSaveStatus = .idle

    // MARK: - Private

    private let resumeParser: ResumeParsing
    private var pendingDownloadURL: String?
    private var pendingUserId: String?

    /// Debounce task for academic details save — cancelled when a new save is triggered.
    private var academicSaveTask: Task<Void, Never>?

    /// Debounce task for preferences save — cancelled when a new save is triggered.
    private var preferencesSaveTask: Task<Void, Never>?

    /// Debounce interval to coalesce rapid changes.
    private static let debounceInterval: Duration = .milliseconds(500)

    /// Maximum wall-clock time for a Firestore write before reporting a timeout.
    private static let saveTimeout: Duration = .seconds(5)

    // MARK: - Init

    /// Creates the ViewModel with a `ResumeParsing` service.
    public init(resumeParser: ResumeParsing) {
        self.resumeParser = resumeParser
    }

    /// Convenience init using raw API key (creates a GeminiResumeParser internally).
    public init(geminiAPIKey: String) {
        self.resumeParser = GeminiResumeParser(apiKey: geminiAPIKey)
    }

    // MARK: - Profile Load

    /// Fetches the user's profile from Firestore on view appear.
    public func loadProfile(userId: String) async {
        guard !isFetchingProfile else { return }
        isFetchingProfile = true
        profileErrorMessage = nil

        do {
            let profile = try await FirestoreService.shared.fetchUserProfile(userId: userId)
            self.profile = profile
            syncProfileToAppState(profile)
        } catch {
            profileErrorMessage = error.localizedDescription
        }

        isFetchingProfile = false
    }

    /// Syncs profile fields to AppState so job filtering, domain selection, and metrics
    /// are restored after app restart or profile reload.
    private func syncProfileToAppState(_ profile: UserProfile) {
        // Sync academic branch and discipline for job filtering
        if let branch = profile.academicBranch {
            AppState.shared.academicBranch = branch
            AppState.shared.selectedDiscipline = branch.discipline
        }

        // Sync preferred roles for role-based filtering
        AppState.shared.preferredRoles = profile.preferredRoles

        // Sync experience level
        if let level = ExperienceLevel(rawValue: profile.experienceLevel) {
            AppState.shared.selectedExperienceLevel = level
        }

        // Sync resume upload state
        AppState.shared.hasUploadedResume = (profile.resumeURL != nil && !profile.resumeURL!.isEmpty)
    }

    // MARK: - Resume Pipeline (Upload → Extract → Parse → Preview)

    /// Runs the pipeline up to the preview step: Upload → Extract → Parse.
    /// After successful parsing, transitions to `.preview` state so the user
    /// can review extracted data before confirming.
    public func processResume(data: Data, userId: String) async {
        guard !pipelineStep.isActive else {
            print("[ResumeParser] ⚠️  Pipeline already active, ignoring duplicate call.")
            return
        }
        parsingState = .parsing
        parsedResume = nil

        // Step 1: Upload to Firebase Storage
        pipelineStep = .uploading
        print("[ResumeParser] 📤 Step 1 — Uploading resume to Firebase Storage…")
        let downloadURL: String
        do {
            downloadURL = try await uploadResume(data: data, userId: userId)
            print("[ResumeParser] ✅ Step 1 complete — Upload successful: \(downloadURL)")
        } catch {
            let message = "Upload failed: \(error.localizedDescription)"
            print("[ResumeParser] ❌ Step 1 failed — \(message)")
            pipelineStep = .failed(message)
            parsingState = .error(message)
            return
        }

        // Step 2: Extract text from PDF using PDFKit
        pipelineStep = .extracting
        print("[ResumeParser] 📄 Step 2 — Extracting text from PDF (\(data.count) bytes)…")
        let resumeText = PDFTextExtractor.extractText(from: data)
        guard resumeText.count >= 50 else {
            let message = "Resume text is too short to parse (\(resumeText.count) chars). Please upload a more detailed PDF."
            print("[ResumeParser] ❌ Step 2 failed — \(message)")
            pipelineStep = .failed(message)
            parsingState = .error(message)
            return
        }
        print("[ResumeParser] ✅ Step 2 complete — Extracted \(resumeText.count) characters of text.")

        // Step 3: Parse via AI service (decoupled)
        pipelineStep = .parsing
        print("[ResumeParser] 🤖 Step 3 — Sending extracted text to AI parser…")
        let parsed: ParsedResume
        do {
            parsed = try await resumeParser.parse(text: resumeText)
            print("[ResumeParser] ✅ Step 3 complete — AI parsing succeeded.")
        } catch let error as ResumeParserError {
            // Step 4: Handle specific parser errors
            let message: String
            switch error {
            case .invalidAPIKey:
                message = "Invalid API key. Check your GeminiAPIKey in Config.plist."
                print("[ResumeParser] ❌ Step 3 failed — Invalid API key detected.")
            case .quotaExceeded:
                message = "API quota exceeded. Wait a moment or enable billing at ai.google.dev."
                print("[ResumeParser] ❌ Step 3 failed — Quota exceeded.")
            default:
                message = "AI parsing failed: \(error.localizedDescription)"
                print("[ResumeParser] ❌ Step 3 failed — \(message)")
            }
            pipelineStep = .failed(message)
            parsingState = .error(message)
            return
        } catch {
            let message = "AI parsing failed: \(error.localizedDescription)"
            print("[ResumeParser] ❌ Step 3 failed — \(message)")
            pipelineStep = .failed(message)
            parsingState = .error(message)
            return
        }

        // Step 4: Store parsed result and present preview to user
        pendingDownloadURL = downloadURL
        pendingUserId = userId
        extractedSkills = parsed.skills
        parsedResume = parsed
        parsingState = .preview(parsed)
        pipelineStep = .preview(parsed)
        print("[ResumeParser] ✅ Step 4 — Preview ready: \(parsed.name) | \(parsed.skills.count) skills | domain: \(parsed.domain)")
    }

    // MARK: - Confirm Auto-fill

    /// Called after the user reviews the preview and confirms.
    /// Merges parsed fields into the profile and saves to Firestore.
    /// After a successful save, triggers a background ATS analysis to populate the metrics.
    public func confirmAutoFill() async {
        guard case .preview(let parsed) = parsingState else { return }
        guard let downloadURL = pendingDownloadURL, let userId = pendingUserId else { return }

        parsingState = .saving
        pipelineStep = .saving

        do {
            let updatedProfile = mergeParsedFields(parsed: parsed, downloadURL: downloadURL, userId: userId)
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Firestore save with a 15-second timeout
                group.addTask {
                    try await FirestoreService.shared.saveUserProfile(profile: updatedProfile)
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(15))
                    throw URLError(.timedOut)
                }
                try await group.next()!
                group.cancelAll()
            }
            profile = updatedProfile
            syncProfileToAppState(updatedProfile)
            AppState.shared.hasCompletedOnboarding = true
            parsingState = .done
            pipelineStep = .done

            // Auto-trigger background ATS analysis for metrics
            runBackgroundATSAnalysis(resumeText: buildResumeText(from: parsed))
        } catch {
            let message: String
            if let urlError = error as? URLError, urlError.code == .timedOut {
                message = "Save timed out. Check your internet connection and Firestore security rules, then try again."
            } else {
                message = "Profile save failed: \(error.localizedDescription)"
            }
            parsingState = .error(message)
            pipelineStep = .failed(message)
        }

        pendingDownloadURL = nil
        pendingUserId = nil
    }

    /// Dismisses the preview without saving, resetting to idle.
    public func dismissPreview() {
        parsingState = .idle
        pendingDownloadURL = nil
        pendingUserId = nil
        pipelineStep = .idle
    }

    /// Resets the pipeline to idle for a fresh attempt.
    public func resetPipeline() {
        pipelineStep = .idle
        parsingState = .idle
        pendingDownloadURL = nil
        pendingUserId = nil
    }

    /// Public setter so the View can trigger pipeline state changes safely.
    public func setPipelineStep(_ step: ResumePipelineStep) {
        pipelineStep = step
    }

    // MARK: - Step 1: Upload (async)

    private func uploadResume(data: Data, userId: String) async throws -> String {
        try await StorageService.shared.uploadResumeAsync(data: data, userId: userId)
    }

    // MARK: - Background ATS Analysis

    /// Builds a plain-text representation of a parsed resume for AI analysis.
    private func buildResumeText(from parsed: ParsedResume) -> String {
        var text = ""
        if !parsed.name.isEmpty { text += "Name: \(parsed.name)\n" }
        if !parsed.email.isEmpty { text += "Email: \(parsed.email)\n" }
        if !parsed.phone.isEmpty { text += "Phone: \(parsed.phone)\n" }
        if !parsed.domain.isEmpty { text += "Domain: \(parsed.domain)\n" }
        if !parsed.experience.isEmpty { text += "Experience Level: \(parsed.experience)\n" }
        if !parsed.skills.isEmpty { text += "Skills: \(parsed.skills.joined(separator: ", "))\n" }
        if !parsed.portfolioLink.isEmpty { text += "Portfolio: \(parsed.portfolioLink)\n" }
        if !parsed.workExperience.isEmpty {
            text += "\nWork Experience:\n"
            for exp in parsed.workExperience {
                text += "- \(exp.role) at \(exp.company) (\(exp.duration))\n"
                if !exp.description.isEmpty { text += "  \(exp.description)\n" }
            }
        }
        if !parsed.projects.isEmpty {
            text += "\nProjects:\n"
            for proj in parsed.projects {
                text += "- \(proj.title) (\(proj.duration))\n"
                if !proj.description.isEmpty { text += "  \(proj.description)\n" }
                if !proj.technologies.isEmpty { text += "  Technologies: \(proj.technologies.joined(separator: ", "))\n" }
            }
        }
        return text
    }

    /// Runs an ATS analysis in the background and updates AppState with the score.
    /// Failures are silently logged — the profile save still succeeds.
    private func runBackgroundATSAnalysis(resumeText: String) {
        guard resumeText.count >= 50 else { return }
        guard let apiKey = getGeminiAPIKey(), !apiKey.isEmpty else { return }

        let aiService = GeminiAIService(apiKey: apiKey)
        Task.detached { [resumeText] in
            do {
                let result = try await aiService.analyzeResume(resumeText)
                await MainActor.run {
                    AppState.shared.updateATSScore(result.matchPercentage)
                    print("[ProfileViewModel] ✅ Background ATS analysis complete: \(result.matchPercentage)/100")
                }
            } catch {
                print("[ProfileViewModel] ⚠️ Background ATS analysis failed: \(error.localizedDescription)")
            }
        }
    }

    /// Reads the Gemini API key from Config.plist.
    private func getGeminiAPIKey() -> String? {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
              let config = NSDictionary(contentsOf: url) as? [String: Any],
              let key = config["GeminiAPIKey"] as? String,
              !key.isEmpty,
              key != "YOUR_GEMINI_API_KEY_HERE"
        else { return nil }
        return key
    }

    // MARK: - Merge parsed fields into UserProfile

    private func mergeParsedFields(parsed: ParsedResume, downloadURL: String, userId: String) -> UserProfile {
        var existing = profile ?? UserProfile(userId: userId)

        // Autofill only non-empty parsed fields (don't overwrite existing data with blanks)
        if !parsed.name.isEmpty { existing.name = parsed.name }
        if !parsed.email.isEmpty { existing.email = parsed.email }
        if !parsed.phone.isEmpty { existing.phone = parsed.phone }
        if !parsed.domain.isEmpty { existing.domain = parsed.domain }
        if !parsed.experience.isEmpty { existing.experienceLevel = parsed.experience }
        if !parsed.skills.isEmpty { existing.skills = parsed.skills }
        if !parsed.portfolioLink.isEmpty { existing.portfolioLink = parsed.portfolioLink }
        if !parsed.projects.isEmpty { existing.projects = parsed.projects }
        if !parsed.workExperience.isEmpty { existing.workExperience = parsed.workExperience }
        existing.resumeURL = downloadURL

        return existing
    }

    // MARK: - Section Update Methods (Optimistic)

    /// Saves updated projects array to Firestore and refreshes the local profile.
    public func updateProjects(_ projects: [Project], userId: String) async {
        guard !userId.isEmpty else { return }
        var updated = profile ?? UserProfile(userId: userId)
        updated.projects = projects
        do {
            try await FirestoreService.shared.saveUserProfile(profile: updated)
            profile = updated
        } catch {
            print("[ProfileViewModel] ❌ Failed to save projects: \(error.localizedDescription)")
        }
    }

    /// Saves updated work experience array to Firestore and refreshes the local profile.
    public func updateWorkExperience(_ workExperience: [WorkExperience], userId: String) async {
        guard !userId.isEmpty else { return }
        var updated = profile ?? UserProfile(userId: userId)
        updated.workExperience = workExperience
        do {
            try await FirestoreService.shared.saveUserProfile(profile: updated)
            profile = updated
        } catch {
            print("[ProfileViewModel] ❌ Failed to save work experience: \(error.localizedDescription)")
        }
    }

    // MARK: - Professional Status Update

    /// Saves the user's professional status fields (experienceLevel, yearOfStudy, yearsOfExperience) to Firestore.
    /// Clears fields that are no longer applicable when the status changes.
    public func updateProfessionalStatus(
        experienceLevel: ExperienceLevel,
        yearOfStudy: Int?,
        yearsOfExperience: Int?,
        userId: String
    ) async {
        guard !userId.isEmpty else { return }

        var fields: [String: Any] = [
            "experienceLevel": experienceLevel.rawValue
        ]

        // Only persist yearOfStudy for students
        if experienceLevel == .student, let yearOfStudy {
            fields["yearOfStudy"] = yearOfStudy
        } else {
            fields["yearOfStudy"] = NSNull()
        }

        // Only persist yearsOfExperience for experienced
        if experienceLevel == .experienced, let yearsOfExperience {
            fields["yearsOfExperience"] = yearsOfExperience
        } else {
            fields["yearsOfExperience"] = NSNull()
        }

        do {
            try await FirestoreService.shared.updateProfileFields(userId: userId, fields: fields)
            await loadProfile(userId: userId)
        } catch {
            print("[ProfileViewModel] ❌ Failed to save professional status: \(error.localizedDescription)")
        }
    }

    /// Saves updated skills array to Firestore and refreshes the local profile.
    public func updateSkills(_ skills: [String], userId: String) async {
        guard !userId.isEmpty else { return }
        var updated = profile ?? UserProfile(userId: userId)
        updated.skills = skills
        do {
            try await FirestoreService.shared.saveUserProfile(profile: updated)
            profile = updated
        } catch {
            print("[ProfileViewModel] ❌ Failed to save skills: \(error.localizedDescription)")
        }
    }

    // MARK: - Optimistic Academic Details Save (Debounced)

    /// Updates local `profile` immediately and fires a debounced background write.
    /// The UI reflects the change instantly; Firestore sync happens silently.
    ///
    /// - Parameters:
    ///   - experienceLevel: The user's professional status.
    ///   - yearOfStudy: Year of study (students only).
    ///   - yearsOfExperience: Years of experience (experienced only).
    ///   - batchYear: Batch / graduation year.
    ///   - academicBranch: Academic domain/branch.
    ///   - preferredRoles: Selected preferred job roles.
    ///   - userId: The Firebase Auth UID.
    public func optimisticSaveAcademicDetails(
        experienceLevel: ExperienceLevel,
        yearOfStudy: Int?,
        yearsOfExperience: Int?,
        batchYear: Int?,
        academicBranch: AcademicDomain?,
        preferredRoles: [TechnicalRole],
        userId: String
    ) {
        guard !userId.isEmpty else { return }

        // 1. Update local state immediately (optimistic)
        var updated = profile ?? UserProfile(userId: userId)
        updated.experienceLevel = experienceLevel.rawValue
        updated.yearOfStudy = experienceLevel == .student ? yearOfStudy : nil
        updated.yearsOfExperience = experienceLevel == .experienced ? yearsOfExperience : nil
        updated.batchYear = batchYear
        updated.academicBranch = academicBranch
        updated.preferredRoles = preferredRoles
        profile = updated

        // Sync to AppState for reactivity
        AppState.shared.selectedExperienceLevel = experienceLevel
        if let branch = academicBranch {
            AppState.shared.selectedDiscipline = branch.discipline
            AppState.shared.academicBranch = branch
        }
        AppState.shared.preferredRoles = preferredRoles

        // 2. Cancel any pending debounced save
        academicSaveTask?.cancel()

        // 3. Set syncing status
        academicSaveStatus = .syncing

        // 4. Debounce — only the final selection triggers the Firestore write
        academicSaveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled else { return }
            await self?.performBackgroundAcademicSave(
                experienceLevel: experienceLevel,
                yearOfStudy: yearOfStudy,
                yearsOfExperience: yearsOfExperience,
                batchYear: batchYear,
                academicBranch: academicBranch,
                preferredRoles: preferredRoles,
                userId: userId
            )
        }
    }

    /// Performs the actual background Firestore writes for academic details.
    private func performBackgroundAcademicSave(
        experienceLevel: ExperienceLevel,
        yearOfStudy: Int?,
        yearsOfExperience: Int?,
        batchYear: Int?,
        academicBranch: AcademicDomain?,
        preferredRoles: [TechnicalRole],
        userId: String
    ) async {
        // Build status fields (as let — no mutation after construction, safe for concurrent capture)
        let statusFields: [String: Any] = {
            var fields: [String: Any] = ["experienceLevel": experienceLevel.rawValue]
            if experienceLevel == .student, let yearOfStudy {
                fields["yearOfStudy"] = yearOfStudy
            } else {
                fields["yearOfStudy"] = NSNull()
            }
            if experienceLevel == .experienced, let yearsOfExperience {
                fields["yearsOfExperience"] = yearsOfExperience
            } else {
                fields["yearsOfExperience"] = NSNull()
            }
            return fields
        }()

        // Build preferences fields (as let — no mutation after construction, safe for concurrent capture)
        let prefFields: [String: Any] = {
            var fields: [String: Any] = [:]
            if let batchYear {
                fields["batchYear"] = batchYear
            } else {
                fields["batchYear"] = NSNull()
            }
            if let academicBranch {
                fields["academicBranch"] = academicBranch.rawValue
            } else {
                fields["academicBranch"] = NSNull()
            }
            fields["preferredRoles"] = preferredRoles.map { $0.rawValue }
            return fields
        }()

        // Fire both writes in parallel with a timeout
        let writer = FirestoreWriter()

        do {
            let results = try await withThrowingTaskGroup(of: ProfileWriteResult.self) { group in
                group.addTask {
                    try await withTimeout(seconds: Self.saveTimeout) {
                        await writer.updateFields(userId: userId, fields: statusFields)
                    }
                }
                group.addTask {
                    try await withTimeout(seconds: Self.saveTimeout) {
                        await writer.updateFields(userId: userId, fields: prefFields)
                    }
                }
                let s = try await group.next()!
                let p = try await group.next()!
                return (s, p)
            }

            if results.0.isSuccess && results.1.isSuccess {
                academicSaveStatus = .saved
                // Auto-dismiss the saved indicator after a short delay
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    self?.academicSaveStatus = .idle
                }
            } else {
                academicSaveStatus = .failed
                // Auto-dismiss the error indicator after a short delay
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    self?.academicSaveStatus = .idle
                }
            }
        } catch {
            academicSaveStatus = .failed
            // Auto-dismiss the error/timeout indicator after a short delay
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                self?.academicSaveStatus = .idle
            }
        }
    }

    // MARK: - Optimistic Preferences Save (Debounced)

    /// Updates local `profile` preferences immediately and fires a debounced background write.
    /// Use this when the user toggles roles or changes batch year independently.
    public func optimisticSavePreferences(
        batchYear: Int?,
        academicBranch: AcademicDomain?,
        preferredRoles: [TechnicalRole],
        userId: String
    ) {
        guard !userId.isEmpty else { return }

        // 1. Update local state immediately (optimistic)
        var updated = profile ?? UserProfile(userId: userId)
        updated.batchYear = batchYear
        updated.academicBranch = academicBranch
        updated.preferredRoles = preferredRoles
        profile = updated

        // Sync to AppState
        if let branch = academicBranch {
            AppState.shared.selectedDiscipline = branch.discipline
            AppState.shared.academicBranch = branch
        }
        AppState.shared.preferredRoles = preferredRoles

        // 2. Cancel any pending debounced save
        preferencesSaveTask?.cancel()

        // 3. Set syncing status
        preferencesSaveStatus = .syncing

        // 4. Debounce — only the final selection triggers the Firestore write
        preferencesSaveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled else { return }
            await self?.performBackgroundPreferencesSave(
                batchYear: batchYear,
                academicBranch: academicBranch,
                preferredRoles: preferredRoles,
                userId: userId
            )
        }
    }

    /// Performs the actual background Firestore write for preferences.
    private func performBackgroundPreferencesSave(
        batchYear: Int?,
        academicBranch: AcademicDomain?,
        preferredRoles: [TechnicalRole],
        userId: String
    ) async {
        let fields: [String: Any] = [
            "batchYear": batchYear.map { $0 as Any } ?? NSNull(),
            "academicBranch": academicBranch.map { $0.rawValue as Any } ?? NSNull(),
            "preferredRoles": preferredRoles.map { $0.rawValue }
        ]

        do {
            let result = try await withTimeout(seconds: Self.saveTimeout) {
                await FirestoreWriter().updateFields(userId: userId, fields: fields)
            }

            if result.isSuccess {
                preferencesSaveStatus = .saved
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    self?.preferencesSaveStatus = .idle
                }
            } else {
                preferencesSaveStatus = .failed
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    self?.preferencesSaveStatus = .idle
                }
            }
        } catch {
            preferencesSaveStatus = .failed
            // Auto-dismiss the error/timeout indicator after a short delay
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                self?.preferencesSaveStatus = .idle
            }
        }
    }

    // MARK: - Professional Preferences Update (Legacy — still available)

    /// Saves the user's academic branch, batch year, and preferred roles to Firestore.
    /// Also updates AppState so the JobListView reacts automatically.
    /// NOTE: For new code, prefer `optimisticSaveAcademicDetails` or `optimisticSavePreferences`.
    public func updateProfessionalPreferences(
        batchYear: Int?,
        academicBranch: AcademicDomain?,
        preferredRoles: [TechnicalRole],
        userId: String
    ) async {
        guard !userId.isEmpty else { return }

        var fields: [String: Any] = [:]

        if let batchYear {
            fields["batchYear"] = batchYear
        } else {
            fields["batchYear"] = NSNull()
        }

        if let academicBranch {
            fields["academicBranch"] = academicBranch.rawValue
        } else {
            fields["academicBranch"] = NSNull()
        }

        fields["preferredRoles"] = preferredRoles.map { $0.rawValue }

        do {
            try await FirestoreService.shared.updateProfileFields(userId: userId, fields: fields)

            // Sync to AppState for reactivity
            AppState.shared.academicBranch = academicBranch
            AppState.shared.preferredRoles = preferredRoles

            // Also sync discipline to match the academic branch
            if let branch = academicBranch {
                AppState.shared.selectedDiscipline = branch.discipline
            }

            await loadProfile(userId: userId)
        } catch {
        print("[ProfileViewModel] ❌ Failed to save professional preferences: \(error.localizedDescription)")
        }
    }
}

// MARK: - Timeout Helper

/// Error thrown when an async operation exceeds the allotted time.
private enum TimeoutError: Error, LocalizedError {
    case exceeded
    var errorDescription: String? { "Network Timeout – Try Again" }
}

/// Runs the given async operation with a wall-clock timeout.
/// If the timeout fires before the operation completes, throws `TimeoutError.exceeded`.
private func withTimeout<T>(seconds: Duration, operation: @Sendable @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(for: seconds)
            throw TimeoutError.exceeded
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
