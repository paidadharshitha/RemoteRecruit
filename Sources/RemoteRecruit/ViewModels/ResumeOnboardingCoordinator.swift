// ResumeOnboardingCoordinator.swift
// RemoteRecruit

import Foundation
import SwiftUI
import PDFKit
import FirebaseAuth
import UniformTypeIdentifiers

// MARK: - Onboarding Phase

/// Represents the onboarding phase after first login.
/// Drives the resume upload prompt and subsequent autofill experience.
public enum OnboardingPhase: Equatable {
    /// Fresh login, no profile data yet — prompt for resume upload.
    case resumeUpload
    /// Resume is being processed through the pipeline.
    case processing(ResumePipelineStep)
    /// Resume parsed — show Confirm Details screen for user verification.
    case confirmDetails(ParsedResume)
    /// Profile confirmed and saved — onboarding complete.
    case complete
    /// Something went wrong during onboarding.
    case failed(String)
    /// Skip onboarding (user opted out or profile already exists).
    case skipped
}

// MARK: - Resume Onboarding Coordinator

/// Bridges the `ProfileViewModel` resume pipeline with the post-login onboarding flow.
/// This coordinator is injected into the ProfileView (or a dedicated onboarding screen)
/// and provides a single entry point: `startOnboarding(data:userId:)`.
///
/// ## Pipeline Architecture
///
/// The full resume autofill flow is a 4-step pipeline orchestrated by `ProfileViewModel`:
///
/// ```
/// User selects PDF
///       │
///       ▼
/// ┌─────────────────┐
/// │ 1. Upload       │  StorageService.uploadResume()
/// │    Resume        │  → Firebase Storage (resumes/{userId}.pdf)
/// │                 │  → downloadURL
/// └────────┬────────┘
///          │
///          ▼
/// ┌─────────────────┐
/// │ 2. Extract Text │  PDFTextExtractor.extractText(from:)
/// │    from PDF     │  → PDFKit page-by-page string extraction
/// │                 │  → resumeText (raw string, min 50 chars)
/// └────────┬────────┘
///          │
///          ▼
/// ┌─────────────────┐
/// │ 3. Parse with   │  ProfileViewModel.parseResumeWithGemini(text:)
/// │    Gemini AI     │  → Structured JSON: {name, email, phone, skills,
/// │                 │     experience, domain}
/// │                 │  → ParsedResume
/// └────────┬────────┘
///          │
///          ▼
/// ┌─────────────────┐
/// │ 4. Save Profile │  mergeParsedFields(parsed:downloadURL:userId:)
/// │    to Firestore │  → UserProfile (autofilled from parsed resume)
/// │                 │  → FirestoreService.saveUserProfile()
/// └─────────────────┘
/// ```
///
/// ## Seamless Autofill Experience
///
/// The `mergeParsedFields()` method in `ProfileViewModel` is the key to seamless autofill:
///
/// - It **only overwrites non-empty fields** — if the user already has a name saved,
///   and the resume parser returns an empty name, the existing value is preserved.
/// - It merges the `resumeURL` so the profile always has a reference to the uploaded PDF.
/// - The `experience` and `domain` fields from Gemini are mapped to `experienceLevel`
///   and `domain` on the `UserProfile` model respectively.
/// - After save, `ProfileView` sees `pipelineStep == .done` and auto-hides the success
///   state after 2 seconds, returning to the idle upload-ready state.
///
/// ## Integration with ProfileView
///
/// The existing `ProfileView` already handles the full pipeline end-to-end:
///
/// 1. User taps "Upload Resume" button → `fileImporter` opens with `.pdf` content type
/// 2. `handleDocumentPicker` reads the PDF data and calls `viewModel.processResume(data:userId:)`
/// 3. `ProfileViewModel.processResume` runs all 4 steps sequentially with `@Published` state
/// 4. `ProfileView.resumeContent` renders the `PipelineStatusView` for each active step
/// 5. On `.done`, profile fields are updated and the user sees their autofilled data
///
/// This coordinator wraps that existing pipeline to provide an onboarding-specific API.
@MainActor
public final class ResumeOnboardingCoordinator: ObservableObject {

    // MARK: - Published State

    /// Current onboarding phase for driving the UI.
    @Published private(set) var phase: OnboardingPhase = .resumeUpload

    /// Reference to the underlying ProfileViewModel that runs the pipeline.
    @Published public var profileViewModel: ProfileViewModel

    /// The user's current profile (loaded from Firestore).
    @Published private(set) var profile: UserProfile?

    // MARK: - Init

    public init(profileViewModel: ProfileViewModel) {
        self.profileViewModel = profileViewModel
    }

    // MARK: - Start Onboarding

    /// Begins the onboarding flow by loading the existing profile.
    /// If a profile already exists with data, onboarding is skipped.
    public func beginOnboarding(userId: String) async {
        await profileViewModel.loadProfile(userId: userId)
        profile = profileViewModel.profile

        // Skip onboarding if profile already has meaningful data
        if let existing = profile, !existing.name.isEmpty {
            phase = .skipped
        } else {
            phase = .resumeUpload
        }
    }

    // MARK: - Process Resume (bridges to ProfileViewModel pipeline)

    /// Triggers the full resume pipeline: Upload → Extract → Parse → Save.
    /// This is the single entry point for the onboarding resume upload.
    ///
    /// - Parameters:
    ///   - data: Raw PDF file data from the document picker.
    ///   - userId: The current user's Firebase Auth UID.
    public func processResume(data: Data, userId: String) async {
        phase = .processing(.uploading)

        // Run the pipeline: Upload → Extract → Parse → Preview
        await profileViewModel.processResume(data: data, userId: userId)

        // If parsing succeeded, transition to confirm details for user verification
        if case .preview(let parsed) = profileViewModel.pipelineStep {
            AppState.shared.hasUploadedResume = true
            phase = .confirmDetails(parsed)
            return
        }

        // If pipeline reached done without preview (edge case), mark complete
        if case .done = profileViewModel.pipelineStep {
            profile = profileViewModel.profile
            AppState.shared.hasUploadedResume = true
            phase = .complete
            return
        }

        // Wait for final terminal state (.failed)
        await waitForPipelineCompletion()
    }

    // MARK: - Skip Onboarding

    /// Allows the user to skip onboarding and proceed to the app.
    public func skipOnboarding() {
        phase = .skipped
    }

    /// Resets the onboarding flow to the initial resume upload state.
    /// Also resets the underlying ProfileViewModel pipeline so it can run again.
    public func resetToResumeUpload() {
        profileViewModel.resetPipeline()
        phase = .resumeUpload
    }

    // MARK: - Confirm Details & Save

    /// Called after the user reviews the pre-filled details and taps "Confirm".
    /// Saves the profile to Firestore and marks onboarding as complete.
    public func confirmAndSave() async {
        // Confirm the auto-fill (saves to Firestore)
        await profileViewModel.confirmAutoFill()

        // Wait for save to complete
        await waitForPipelineCompletion()

        // Update phase to complete
        if case .done = profileViewModel.pipelineStep {
            profile = profileViewModel.profile
            phase = .complete
        }
    }

    /// Allows the user to go back to resume upload from the confirm details screen.
    public func backToResumeUpload() {
        profileViewModel.dismissPreview()
        AppState.shared.hasUploadedResume = false
        phase = .resumeUpload
    }
    
    /// Sets the onboarding phase to failed with a provided message.
    public func fail(with message: String) {
        phase = .failed(message)
    }

    // MARK: - Private Helpers

    private func waitForPipelineCompletion() async {
        // Poll the pipeline step until it reaches a terminal state
        let timeout: TimeInterval = 120 // 2 minutes max for full pipeline
        let startTime = Date()

        while true {
            let step = profileViewModel.pipelineStep

            // Update phase to reflect current pipeline step
            switch step {
            case .uploading, .extracting, .parsing, .saving:
                phase = .processing(step)
            case .preview:
                // Preview — waiting for user to confirm in ProfileConfirmView
                return
            case .done:
                profile = profileViewModel.profile
                phase = .complete
                return
            case .failed(let message):
                phase = .failed(message)
                return
            case .idle:
                // Pipeline was reset externally
                if phase == .processing(.uploading) {
                    // Still waiting for first step
                    break
                }
                return
            @unknown default:
                // Handle any future cases conservatively
                phase = .failed("Unexpected pipeline state. Please try again.")
                return
            }

            // Timeout protection
            if Date().timeIntervalSince(startTime) > timeout {
                phase = .failed("Resume processing timed out. Please try again.")
                return
            }

            // Yield to avoid busy-waiting
            try? await Task.sleep(for: .milliseconds(200))
        }
    }
}

// MARK: - Onboarding View Extension

extension View {

    /// Presents a resume upload onboarding sheet if the coordinator is in `.resumeUpload` phase.
    /// Integrates the 4-step pipeline status into the onboarding UI.
    ///
    /// Usage:
    /// ```swift
    /// ProfileView()
    ///     .onboardingSheet(coordinator: onboardingCoordinator) {
    ///         AppState.shared.hasCompletedOnboarding = true
    ///     }
    /// ```
    public func onboardingSheet(coordinator: ResumeOnboardingCoordinator, onContinue: @escaping () -> Void) -> some View {
        self.sheet(isPresented: Binding(
            get: {
                switch coordinator.phase {
                case .resumeUpload:
                    return true
                case .processing(let step):
                    switch step {
                    case .uploading, .extracting, .parsing, .saving, .preview:
                        return true
                    default:
                        return false
                    }
                case .confirmDetails:
                    return true
                default:
                    return false
                }
            },
            set: { _ in }
        )) {
            Group {
                switch coordinator.phase {
                case .confirmDetails(_):
                    ProfileConfirmView(coordinator: coordinator, onConfirm: onContinue)
                default:
                    OnboardingResumeView(coordinator: coordinator, onContinue: onContinue)
                }
            }
        }
    }
}

// MARK: - Onboarding Resume View

/// Dedicated view for the onboarding resume upload experience.
/// Shows a prompt, file picker, and pipeline progress.
/// Resume upload is mandatory — the "Continue to Home" button is disabled
/// until the resume has been successfully parsed and the profile updated.
public struct OnboardingResumeView: View {

    @ObservedObject var coordinator: ResumeOnboardingCoordinator

    /// Called when the user taps "Continue to Home" after successful resume processing.
    var onContinue: () -> Void

    @State private var showDocumentPicker = false

    /// Whether the resume has been successfully processed and the user can proceed.
    private var canContinue: Bool {
        if case .complete = coordinator.phase { return true }
        return false
    }

    public init(coordinator: ResumeOnboardingCoordinator, onContinue: @escaping () -> Void) {
        self.coordinator = coordinator
        self.onContinue = onContinue
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Header
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Upload Your Resume")
                        .font(.title2.bold())
                    Text("We'll automatically extract your details to fill out your profile.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Pipeline Status
                if case .processing(let step) = coordinator.phase {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                        Text(step.displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }

                // Completion
                if case .complete = coordinator.phase {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("Resume processed successfully!")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }

                // Error
                if case .failed(let message) = coordinator.phase {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Button("Try Again") {
                            coordinator.resetToResumeUpload()
                        }
                        .font(.caption.weight(.semibold))
                    }
                }

                Spacer()

                // Action Buttons
                if case .resumeUpload = coordinator.phase {
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("Select Resume (PDF)", systemImage: "arrow.up.doc.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 32)
                }

                // Continue to Home — only enabled after resume is processed
                Button {
                    onContinue()
                } label: {
                    Label("Continue to Home", systemImage: "house.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            canContinue ? Color.green : Color.gray.opacity(0.4),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .disabled(!canContinue)
                .padding(.horizontal, 32)
            }
            .padding(.top, 40)
            .navigationTitle("Get Started")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [.pdf],
                onCompletion: handleDocumentPicker
            )
        }
    }

    private func handleDocumentPicker(_ result: Result<URL, Error>) {
        showDocumentPicker = false

        guard case .success(let pickerURL) = result else {
            coordinatorFailed("Could not access the selected file.")
            return
        }

        // Access the security-scoped resource
        guard pickerURL.startAccessingSecurityScopedResource() else {
            coordinatorFailed("Could not access the selected file.")
            return
        }
        defer { pickerURL.stopAccessingSecurityScopedResource() }

        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            coordinatorFailed("You must be signed in to upload a resume.")
            return
        }

        // Securely copy the file into the app's Documents/Resumes/ directory
        let persistentURL: URL
        do {
            persistentURL = try StorageService.secureCopyResumeFromPicker(pickerURL)
        } catch {
            coordinatorFailed("Could not copy resume: \(error.localizedDescription)")
            return
        }

        // Read data from the persistent copy (not the temporary picker URL)
        let data: Data
        do {
            data = try StorageService.readData(from: persistentURL)
        } catch {
            coordinatorFailed("Could not read copied resume: \(error.localizedDescription)")
            return
        }

        print("[ResumeOnboarding] Resume securely copied to: \(persistentURL.path)")

        Task {
            await coordinator.processResume(data: data, userId: uid)
        }
    }

    private func coordinatorFailed(_ message: String) {
        Task { @MainActor in
            coordinator.fail(with: message)
        }
    }
}

