// AppState.swift
// RemoteRecruit

import Foundation
import SwiftUI
import Combine

// MARK: - Academic Domain

/// Represents a student's engineering/academic branch for profile preferences.
/// Maps to `AcademicDiscipline` for job filtering purposes.
public enum AcademicDomain: String, Codable, CaseIterable, Identifiable, Sendable {
    case cse = "CSE"
    case ece = "ECE"
    case eee = "EEE"
    case mechanical = "Mechanical"

    public var id: String { rawValue }

    /// Display name for UI.
    public var displayName: String {
        switch self {
        case .cse: return "Computer Science & Engineering"
        case .ece: return "Electronics & Communication Engineering"
        case .eee: return "Electrical & Electronics Engineering"
        case .mechanical: return "Mechanical Engineering"
        }
    }

    /// System icon for visual identification.
    public var iconName: String {
        switch self {
        case .cse: return "desktopcomputer"
        case .ece: return "microchip"
        case .eee: return "bolt.fill"
        case .mechanical: return "gearshape.2"
        }
    }

    /// Maps to the corresponding `AcademicDiscipline` for filter compatibility.
    public var discipline: AcademicDiscipline {
        switch self {
        case .cse: return .computerScience
        case .ece: return .electronicsAndCommunication
        case .eee: return .electricalAndElectronics
        case .mechanical: return .mechanical
        }
    }

    /// Returns the `JobDomain` roles associated with this branch.
    public var mappedJobDomains: [JobDomain] {
        discipline.mappedRoles
    }
}

// MARK: - Technical Role

/// User-facing role labels that map to one or more `JobDomain` values for filtering.
/// Users select these in their profile; jobs are filtered by matching the mapped domains.
public enum TechnicalRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case frontend = "Frontend"
    case backend = "Backend"
    case mobile = "Mobile (iOS)"
    case webDeveloper = "Web Developer"
    case aiSpecialist = "AI Specialist"
    case dataScientist = "Data Scientist"
    case dataEngineer = "Data Engineer"
    case softwareDeveloper = "Software Developer"
    case embeddedSystems = "Embedded Systems"
    case vlsi = "VLSI"
    case firmware = "Firmware"
    case hardwareEngineer = "Hardware Engineer"
    case powerSystems = "Power Systems"
    case controlSystems = "Control Systems"
    case electricalDesigner = "Electrical Designer"
    case cadDesigner = "CAD Designer"
    case productDesign = "Product Design"
    case thermalEngineer = "Thermal Engineer"
    case productDesigner = "Product Designer"

    public var id: String { rawValue }

    /// System icon for visual identification.
    public var iconName: String {
        switch self {
        case .frontend: return "globe"
        case .backend: return "server.rack"
        case .mobile: return "iphone"
        case .webDeveloper: return "globe"
        case .aiSpecialist: return "brain"
        case .dataScientist: return "chart.bar.doc.horizontal"
        case .dataEngineer: return "cylinder.split.1x2.fill"
        case .softwareDeveloper: return "chevron.left.forwardslash.chevron.right"
        case .embeddedSystems: return "microchip"
        case .vlsi: return "memorychip"
        case .firmware: return "hammer"
        case .hardwareEngineer: return "internaldrive"
        case .powerSystems: return "bolt.fill"
        case .controlSystems: return "gauge.with.dots.needle.bottom.50percent"
        case .electricalDesigner: return "lightbulb.led"
        case .cadDesigner: return "pencil.and.ruler"
        case .productDesign: return "cube"
        case .thermalEngineer: return "thermometer.medium"
        case .productDesigner: return "paintbrush"
        }
    }

    /// Maps this user-facing role to the `JobDomain` values used for job matching.
    public var mappedJobDomains: [JobDomain] {
        switch self {
        case .frontend: return [.webDeveloper, .iosDeveloper]
        case .backend: return [.backendEngineer]
        case .mobile: return [.iosDeveloper]
        case .webDeveloper: return [.webDeveloper]
        case .aiSpecialist: return [.aiSpecialist]
        case .dataScientist: return [.dataScientist]
        case .dataEngineer: return [.dataEngineer]
        case .softwareDeveloper: return [.softwareDeveloper]
        case .embeddedSystems: return [.embeddedSystemsEngineer]
        case .vlsi: return [.vlsiEngineer]
        case .firmware: return [.firmwareDeveloper]
        case .hardwareEngineer: return [.hardwareEngineer]
        case .powerSystems: return [.powerSystemsEngineer]
        case .controlSystems: return [.controlSystemsEngineer]
        case .electricalDesigner: return [.electricalDesigner]
        case .cadDesigner: return [.cadDesigner]
        case .productDesign: return [.productDesignEngineer]
        case .thermalEngineer: return [.thermalEngineer]
        case .productDesigner: return [.productDesigner]
        }
    }

    /// The academic branch(es) this role naturally belongs to.
    public var primaryBranch: AcademicDomain? {
        switch self {
        case .frontend, .backend, .mobile, .webDeveloper, .aiSpecialist,
             .dataScientist, .dataEngineer, .softwareDeveloper:
            return .cse
        case .embeddedSystems, .vlsi, .firmware, .hardwareEngineer:
            return .ece
        case .powerSystems, .controlSystems, .electricalDesigner:
            return .eee
        case .cadDesigner, .productDesign, .thermalEngineer:
            return .mechanical
        case .productDesigner:
            return nil
        }
    }

    /// Roles grouped by academic branch for contextual display.
    public static func roles(forBranch branch: AcademicDomain) -> [TechnicalRole] {
        allCases.filter { $0.primaryBranch == branch }
    }
}

// MARK: - Academic Discipline

/// Represents a student's engineering/academic branch.
/// Used as the primary filter that maps to specific job roles.
public enum AcademicDiscipline: String, Codable, CaseIterable, Identifiable, Sendable {
    case computerScience = "Computer Science"
    case electronicsAndCommunication = "Electronics & Communication"
    case electricalAndElectronics = "Electrical & Electronics"
    case mechanical = "Mechanical"

    public var id: String { rawValue }

    /// Short display name for UI pills and tags.
    public var shortName: String {
        switch self {
        case .computerScience: return "CS"
        case .electronicsAndCommunication: return "ECE"
        case .electricalAndElectronics: return "EEE"
        case .mechanical: return "Mech"
        }
    }

    /// System icon for visual identification.
    public var iconName: String {
        switch self {
        case .computerScience: return "desktopcomputer"
        case .electronicsAndCommunication: return "microchip"
        case .electricalAndElectronics: return "bolt.fill"
        case .mechanical: return "gearshape.2"
        }
    }

    /// Accent color for the discipline.
    public var accentColor: String {
        switch self {
        case .computerScience: return "blue"
        case .electronicsAndCommunication: return "purple"
        case .electricalAndElectronics: return "orange"
        case .mechanical: return "green"
        }
    }

    /// Maps this discipline to the specific job domains/roles relevant to it.
    /// Extensible — add a new case and return its mapped roles here.
    public var mappedRoles: [JobDomain] {
        switch self {
        case .computerScience:
            return [.softwareDeveloper, .dataEngineer, .webDeveloper, .aiSpecialist]
        case .electronicsAndCommunication:
            return [.embeddedSystemsEngineer, .vlsiEngineer, .firmwareDeveloper]
        case .electricalAndElectronics:
            return [.powerSystemsEngineer, .controlSystemsEngineer, .electricalDesigner]
        case .mechanical:
            return [.cadDesigner, .productDesignEngineer, .thermalEngineer]
        }
    }
}

// MARK: - User Domain

public enum JobDomain: String, Codable, CaseIterable, Identifiable, Sendable {
    // Original domains
    case iosDeveloper = "iOS Developer"
    case backendEngineer = "Backend Engineer"
    case productDesigner = "Product Designer"
    case dataScientist = "Data Scientist"
    // CS-mapped domains
    case softwareDeveloper = "Software Developer"
    case dataEngineer = "Data Engineer"
    case webDeveloper = "Web Developer"
    case aiSpecialist = "AI Specialist"
    // ECE-mapped domains
    case embeddedSystemsEngineer = "Embedded Systems Engineer"
    case hardwareEngineer = "Hardware Engineer"
    case vlsiEngineer = "VLSI Engineer"
    case firmwareDeveloper = "Firmware Developer"
    // EEE-mapped domains
    case powerSystemsEngineer = "Power Systems Engineer"
    case controlSystemsEngineer = "Control Systems Engineer"
    case electricalDesigner = "Electrical Designer"
    // Mechanical-mapped domains
    case cadDesigner = "CAD Designer"
    case productDesignEngineer = "Product Design Engineer"
    case thermalEngineer = "Thermal Engineer"

    public var id: String { rawValue }

    /// Keywords that map a job to this domain.
    public var keywords: [String] {
        switch self {
        case .iosDeveloper: return ["ios", "swift", "swiftui", "mobile", "apple"]
        case .backendEngineer: return ["backend", "server", "api", "go", "rust", "python"]
        case .productDesigner: return ["design", "ux", "ui", "figma", "product"]
        case .dataScientist: return ["data", "machine learning", "ml", "python", "analytics"]
        case .softwareDeveloper: return ["software", "developer", "fullstack", "full-stack", "sde", "programming"]
        case .dataEngineer: return ["data engineer", "etl", "pipeline", "data warehouse", "spark", "kafka"]
        case .webDeveloper: return ["web", "frontend", "react", "javascript", "html", "css", "vue"]
        case .aiSpecialist: return ["ai", "artificial intelligence", "deep learning", "nlp", "computer vision", "llm"]
        case .embeddedSystemsEngineer: return ["embedded", "firmware", "microcontroller", "rtos", "iot", "c/c++"]
        case .hardwareEngineer: return ["hardware", "fpga", "pcb", "rtl", "verilog", "vhdl"]
        case .vlsiEngineer: return ["vlsi", "asic", "soc", "rtl", "verilog", "vhdl", "tapeout"]
        case .firmwareDeveloper: return ["firmware", "bare-metal", "bootloader", "driver", "embedded c", "mcu"]
        case .powerSystemsEngineer: return ["power systems", "electrical", "substation", "transmission", "distribution"]
        case .controlSystemsEngineer: return ["control systems", "plc", "scada", "automation", "instrumentation", "pid"]
        case .electricalDesigner: return ["electrical design", "schematic", "panel", "wiring", "revit", "autocad electrical"]
        case .cadDesigner: return ["cad", "solidworks", "autocad", "catia", "creo", "nx", "3d modeling"]
        case .productDesignEngineer: return ["product design", "dfm", "prototyping", "tolerancing", "gd&t"]
        case .thermalEngineer: return ["thermal", "heat transfer", "cfd", "fea", "cooling", "thermal management"]
        }
    }

    /// The academic discipline this domain primarily belongs to (nil if it spans multiple).
    public var primaryDiscipline: AcademicDiscipline? {
        switch self {
        case .softwareDeveloper, .dataEngineer, .webDeveloper, .aiSpecialist: return .computerScience
        case .embeddedSystemsEngineer, .vlsiEngineer, .firmwareDeveloper: return .electronicsAndCommunication
        case .powerSystemsEngineer, .controlSystemsEngineer, .electricalDesigner: return .electricalAndElectronics
        case .cadDesigner, .productDesignEngineer, .thermalEngineer: return .mechanical
        default: return nil
        }
    }

    /// System icon for visual identification.
    public var iconName: String {
        switch self {
        case .iosDeveloper: return "iphone"
        case .backendEngineer: return "server.rack"
        case .productDesigner: return "paintbrush"
        case .dataScientist: return "chart.bar.doc.horizontal"
        case .softwareDeveloper: return "chevron.left.forwardslash.chevron.right"
        case .dataEngineer: return "cylinder.split.1x2.fill"
        case .webDeveloper: return "globe"
        case .aiSpecialist: return "brain"
        case .embeddedSystemsEngineer: return "microchip"
        case .hardwareEngineer: return "internaldrive"
        case .vlsiEngineer: return "memorychip"
        case .firmwareDeveloper: return "hammer"
        case .powerSystemsEngineer: return "bolt.fill"
        case .controlSystemsEngineer: return "gauge.with.dots.needle.bottom.50percent"
        case .electricalDesigner: return "lightbulb.led"
        case .cadDesigner: return "pencil.and.ruler"
        case .productDesignEngineer: return "cube"
        case .thermalEngineer: return "thermometer.medium"
        }
    }
}

// MARK: - Experience Level

public enum ExperienceLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case student = "Student"
    case fresher = "Fresher"
    case experienced = "Experienced"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .student: return "Internship"
        case .fresher: return "Entry Level"
        case .experienced: return "Experienced"
        }
    }
}

// MARK: - App State (shared @Observable)

/// Centralized application state manager using Swift Observation framework.
/// Tracks auth, domain selection, and application metrics in a single isolated store.
@MainActor
public final class AppState: ObservableObject {

    // MARK: - Singleton

    /// Single shared instance used across the entire app to prevent dual-instance confusion.
    public static let shared = AppState()

    // MARK: - Auth

    /// Tracks whether the user has an active session.
    @Published private(set) var isLoggedIn = false
    @Published private(set) var username: String = ""

    /// Whether the user has uploaded and parsed their resume.
    /// Set to `true` after `ResumeOnboardingCoordinator` successfully parses the resume.
    /// Reset to `false` on logout.
    @Published var hasUploadedResume = false

    /// Whether the user has confirmed their profile details after resume parsing.
    /// Set to `true` after the user taps "Confirm" on the ProfileConfirmView.
    /// Reset to `false` on logout.
    @Published var hasCompletedOnboarding = false

    // MARK: - Profile / Domain Selection

    /// The currently selected job domain used for filtering and recommendations.
    @Published var selectedDomain: JobDomain = .iosDeveloper

    /// The user's academic discipline (CS, ECE, EEE) used as the primary filter.
    @Published var selectedDiscipline: AcademicDiscipline = .computerScience

    /// The user's career experience status for profile filtering.
    @Published var selectedExperienceLevel: ExperienceLevel = .student

    /// The current search query for filtering jobs by title, company, or tags.
    @Published var searchText: String = ""

    // MARK: - Skills & Gap Analysis

    /// The user's current skills list (synced from profile for gap analysis).
    @Published var profileSkills: [String] = []

    /// Whether the gap analysis sheet should be shown.
    @Published var showGapAnalysis = false

    /// The job selected for gap analysis.
    @Published var gapAnalysisJob: Job?

    // MARK: - Professional Preferences (role-based filtering)

    /// The user's academic branch from their profile (CSE, ECE, EEE, Mechanical).
    @Published var academicBranch: AcademicDomain?

    /// The user's preferred technical roles (e.g., Frontend, Backend, AI Specialist).
    /// When empty, all jobs for the user's academic branch are shown.
    @Published var preferredRoles: [TechnicalRole] = []

    // MARK: - Metrics

    /// Total number of jobs the user has applied to.
    @Published private(set) var jobsAppliedCount: Int = 0

    /// Most recent ATS (Applicant Tracking System) compatibility score (0–100).
    @Published private(set) var latestATSScore: Int = 0

    // MARK: - Computed

    /// Convenience accessor for the selected domain's display name.
    var selectedDomainName: String {
        selectedDomain.rawValue
    }

    // MARK: - Domain Filter

    /// Returns whether a job matches the user's selected domain.
    func jobMatchesDomain(_ job: Job) -> Bool {
        let query = selectedDomain.rawValue.lowercased()
        let allText = "\(job.title) \(job.companyName) \(job.jobDescription) \(job.tags.joined(separator: " "))".lowercased()
        return selectedDomain.keywords.contains(where: { allText.contains($0) })
            || allText.contains(query)
    }

    // MARK: - Experience Level Filter

    /// Returns whether a job matches the user's selected experience level.
    func jobMatchesExperienceLevel(_ job: Job) -> Bool {
        let title = job.title.lowercased()
        let allTags = job.tags.map { $0.lowercased() }

        switch selectedExperienceLevel {
        case .student:
            // Show only intern/co-op roles
            let internKeywords = ["intern", "internship", "co-op", "co op"]
            return internKeywords.contains(where: { title.contains($0) })
                || allTags.contains(where: { $0.contains("intern") || $0.contains("co-op") })
        case .fresher:
            // Show entry-level roles, screen out senior/lead/staff titles
            let seniorKeywords = ["senior", "lead", "staff", "principal", "sr."]
            let hasSenior = seniorKeywords.contains(where: { title.contains($0) })
                || allTags.contains(where: { $0.contains("senior") || $0.contains("lead") || $0.contains("staff") })
            return !hasSenior
        case .experienced:
            // Show all roles (no experience-level filtering)
            return true
        }
    }

    // MARK: - Search Text Filter

    /// Returns whether a job matches the user's current search query.
    func jobMatchesSearchText(_ job: Job) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return job.title.localizedCaseInsensitiveContains(query)
            || job.companyName.localizedCaseInsensitiveContains(query)
            || job.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) })
    }

    // MARK: - Auth Actions

    func login(username: String, password: String) {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        self.username = username
        self.isLoggedIn = true
    }

    func logout() {
        isLoggedIn = false
        username = ""
        hasUploadedResume = false
        hasCompletedOnboarding = false
        jobsAppliedCount = 0
        latestATSScore = 0
    }

    // MARK: - Metrics Actions

    func incrementJobsApplied() {
        jobsAppliedCount += 1
    }

    func updateATSScore(_ score: Int) {
        latestATSScore = min(max(score, 0), 100)
    }

    private init() {
        // Sync auth state from Firebase on cold launch.
        // AuthService.shared is @MainActor and is already initialized by the time
        // AppState.shared is first accessed, so this is safe.
        syncFromFirebase()
    }

    // MARK: - Firebase Sync

    /// Called once at init and then reactively whenever the auth state changes.
    func syncFromFirebase() {
        let user = AuthService.shared.user
        isLoggedIn = (user != nil)
        if let email = user?.email, !email.isEmpty {
            username = email.components(separatedBy: "@").first ?? email
        }
    }
}

// MARK: - ATS Analysis Result

public struct ATSAnalysisResult: Codable, Equatable, Sendable {
    public let matchPercentage: Int
    public let missingKeywords: [String]
    public let suggestions: [String]
    public let rawResponse: String

    public init(
        matchPercentage: Int,
        missingKeywords: [String],
        suggestions: [String],
        rawResponse: String = ""
    ) {
        self.matchPercentage = matchPercentage
        self.missingKeywords = missingKeywords
        self.suggestions = suggestions
        self.rawResponse = rawResponse
    }
}
