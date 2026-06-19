// ApplyFormView.swift
// RemoteRecruit

import SwiftUI
import FirebaseFirestore
import UniformTypeIdentifiers

// MARK: - Apply Form View

/// A full-screen application form pre-filled with the user's profile data.
/// Presented when the user taps "Apply" from JobDetailView.
struct ApplyFormView: View {

    #if os(iOS)
    private static let borderColor = Color(uiColor: .systemFill)
    #else
    private static let borderColor = Color(NSColor.separatorColor)
    #endif

    // MARK: - Dependencies

    let job: Job
    let applyService: ApplyServiceProtocol

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var college: String = ""
    @State private var domain: String = ""
    @State private var experienceLevel: String = ""
    @State private var skills: String = ""
    @State private var portfolioLink: String = ""
    @State private var resumeURL: String = ""

    @State private var coverNote: String = ""
    @State private var applyState: ApplyState = .idle
    @State private var isFormLoaded = false
    @State private var showDocumentPicker = false
    @State private var attachedResumeURL: String = ""

    // MARK: - Init

    init(job: Job, applyService: ApplyServiceProtocol = DIContainer.shared.applyService) {
        self.job = job
        self.applyService = applyService
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Job summary card
                    jobSummaryCard

                    // Personal info section
                    formSection(header: "Personal Information") {
                        formRow(title: "Full Name", icon: "person.fill", field: $fullName)
                        formRow(title: "Email", icon: "envelope.fill", field: $email)
                        formRow(title: "Phone", icon: "phone.fill", field: $phone)
                    }

                    // Education section
                    formSection(header: "Education & Experience") {
                        formRow(title: "College / University", icon: "building.columns.fill", field: $college)
                        formRow(title: "Domain", icon: "tag.fill", field: $domain)
                        formRow(title: "Experience Level", icon: "chart.bar.fill", field: $experienceLevel)
                    }

                    // Skills section
                    formSection(header: "Skills & Portfolio") {
                        formRow(title: "Key Skills", icon: "star.fill", field: $skills)
                        formRow(title: "Portfolio Link", icon: "link", field: $portfolioLink)
                    }

                    // Cover note
                    formSection(header: "Cover Note (Optional)") {
                        TextEditor(text: $coverNote)
                            .frame(minHeight: 100)
                            .padding(12)
#if os(iOS)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
#else
                            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
#endif
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Self.borderColor, lineWidth: 1)
                            )
                    }

                    // Resume attachment section
                    resumeAttachmentSection
                        .padding(.top, 8)

                    // Apply section
                    applySection
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Apply")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
#if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
#else
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") { dismiss() }
                }
            }
#endif
            .safeAreaInset(edge: .bottom) {
                if case .idle = applyState {
                    floatingApplyButton
                }
            }
        }
        .task {
            await loadUserProfile()
        }
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.pdf],
            onCompletion: handleResumePicker
        )
    }

    // MARK: - Job Summary Card

    private var jobSummaryCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(.tint.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay {
                    Text(String(job.companyName.prefix(1)))
                        .font(.title2.bold())
                        .foregroundStyle(.tint)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(job.title)
                    .font(.subheadline.weight(.semibold))
                Text(job.companyName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(job.salaryRange)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.1), in: Capsule())
        }
        .padding(14)
#if os(iOS)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
#else
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
#endif
    }

    // MARK: - Form Section Builder

    private func formSection<Content: View>(header: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(header)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content()
        }
    }

    // MARK: - Form Row

    private func formRow(title: String, icon: String, field: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Enter \(title.lowercased())", text: field)
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding(12)
#if os(iOS)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
#else
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
#endif
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Self.borderColor, lineWidth: 1)
        )
    }

    // MARK: - Resume Attachment Section

    /// Displays the current resume status and allows attaching a resume
    /// directly from this form when the profile resume is missing or stale.
    private var resumeAttachmentSection: some View {
        formSection(header: "Resume") {
            VStack(alignment: .leading, spacing: 12) {
                if !attachedResumeURL.isEmpty {
                    // Attached resume — show file name with option to replace
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.body)
                            .foregroundStyle(.green)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Resume attached")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(URL(string: attachedResumeURL)?.lastPathComponent ?? "Resume")
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)

                        Button("Replace") {
                            showDocumentPicker = true
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
                    )
                } else if !resumeURL.isEmpty {
                    // Profile resume exists — show as read-only
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.body)
                            .foregroundStyle(.tint)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Resume from profile")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text("Using your uploaded resume")
                                .font(.subheadline.weight(.medium))
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.tint)
                    }
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Self.borderColor, lineWidth: 1)
                    )
                } else {
                    // No resume — prompt to attach
                    Button {
                        showDocumentPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "paperclip")
                                .font(.body)
                                .foregroundStyle(.tint)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Attach Resume (PDF)")
                                    .font(.subheadline.weight(.medium))
                                Text("Tap to select a file from your device")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.tint.opacity(0.6))
                        }
                        .padding(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Resume Picker Handler

    /// Handles the document picker result, securely copies the file into the
    /// app's Documents/Resumes/ directory, and stores the persistent URL.
    private func handleResumePicker(_ result: Result<URL, Error>) {
        showDocumentPicker = false

        guard case .success(let pickerURL) = result else {
            applyState = .error(message: "Could not access the selected file.")
            return
        }

        // Access the security-scoped resource
        let didGainAccess = pickerURL.startAccessingSecurityScopedResource()
        defer { pickerURL.stopAccessingSecurityScopedResource() }

        guard didGainAccess else {
            applyState = .error(message: "Permission denied: the app cannot read the selected file.")
            return
        }

        // Securely copy into Documents/Resumes/
        let persistentURL: URL
        do {
            persistentURL = try StorageService.secureCopyResumeFromPicker(pickerURL)
        } catch {
            applyState = .error(message: "Could not copy resume: \(error.localizedDescription)")
            return
        }

        // Verify file exists at the persistent path
        let fm = FileManager.default
        guard fm.fileExists(atPath: persistentURL.path) else {
            print("[ApplyFormView] ❌ Copied file does not exist at: \(persistentURL.path)")
            applyState = .error(message: "Resume copy verification failed. Please try again.")
            return
        }

        attachedResumeURL = persistentURL.absoluteString
        print("[ApplyFormView] Resume securely attached at: \(persistentURL.path)")
    }

    // MARK: - Apply Section

    private var applySection: some View {
        VStack(spacing: 16) {
            switch applyState {
            case .idle:
                Color.clear.frame(height: 0)

            case .checkingDuplicate:
                HStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking for existing application…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
#if os(iOS)
                .background(Color(uiColor: .secondarySystemFill), in: RoundedRectangle(cornerRadius: 12))
#else
                .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
#endif

            case .submitting:
                HStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Submitting your application…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(.tint, in: RoundedRectangle(cornerRadius: 12))

            case .submitted:
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                    Text("Submitted")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            case .success:
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                    Text("Application submitted successfully!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            case .error(let message):
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    Button("Try Again") { applyState = .idle }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .padding(12)
                .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Floating Apply Button

    private var floatingApplyButton: some View {
        Button {
            handleSubmit()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "paperplane.fill")
                Text("Submit Application")
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.tint, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Profile Loading

    private func loadUserProfile() async {
        guard !isFormLoaded else { return }
        guard let user = AuthService.shared.user, !user.uid.isEmpty else { return }

        do {
            let profile = try await FirestoreService.shared.fetchUserProfile(userId: user.uid)
            fullName = profile.name
            email = profile.email
            phone = profile.phone
            college = profile.college
            domain = profile.domain
            experienceLevel = profile.experienceLevel
            skills = profile.skills.joined(separator: ", ")
            portfolioLink = profile.portfolioLink
            resumeURL = profile.resumeURL ?? ""
            isFormLoaded = true
        } catch {
            print("[ApplyFormView] Failed to load profile: \(error.localizedDescription)")
        }
    }

    // MARK: - Submit Handler

    private static let applyTimeout: Duration = .seconds(5)

    private func handleSubmit() {
        guard let user = AuthService.shared.user, !user.uid.isEmpty else {
            applyState = .error(message: "Please sign in to apply.")
            return
        }

        guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
            applyState = .error(message: "Please enter your full name.")
            return
        }

        // Prefer the attached resume (already securely copied) over the profile resume
        let rawResumeURL = attachedResumeURL.isEmpty ? resumeURL : attachedResumeURL
        let resolved = ResumePathResolver.resolve(rawResumeURL.isEmpty ? nil : rawResumeURL)
        let resumeToUse: String

        switch resolved {
        case .found(let localPath):
            // Local file exists — use the resolved file URL
            resumeToUse = URL(fileURLWithPath: localPath).absoluteString
            print("[ApplyFormView] Resume file found: \(localPath)")

        case .notFound(let resolvedPath, let rawURL):
            // Local file:// URL but the file doesn't exist on this device
            print("[ApplyFormView] ❌ Resume file NOT found.")
            print("[ApplyFormView]    Resolved path: \(resolvedPath)")
            print("[ApplyFormView]    Raw URL from Firestore: \(rawURL)")
            print("[ApplyFormView]    This likely means the resume was uploaded on a different device or simulator,")
            print("[ApplyFormView]    or the app sandbox has changed. The user needs to re-upload.")
            applyState = .error(
                message: "Resume file not found at the stored path. Please attach a resume using the button above or re-upload from your profile."
            )
            return

        case .remote(let urlString):
            // Firebase/HTTPS URL — pass through directly
            resumeToUse = urlString
            print("[ApplyFormView] Using remote resume URL: \(urlString)")

        case .invalidFormat(let raw):
            // Empty or malformed — allow if user has no resume at all (will be caught by validation plugin)
            if raw.isEmpty {
                resumeToUse = ""
                print("[ApplyFormView] No resume URL provided.")
            } else {
                print("[ApplyFormView] ❌ Resume URL is malformed: \"\(raw)\"")
                applyState = .error(
                    message: "Resume URL is invalid. Please attach a resume or re-upload from your profile."
                )
                return
            }
        }

        // Final verification: if a local path was resolved, confirm the file still exists
        if let url = URL(string: resumeToUse), url.isFileURL {
            let fm = FileManager.default
            let path = url.path(percentEncoded: false)
            let exists = fm.fileExists(atPath: path)
            print("[ApplyFormView] Pre-submit file check: \(path) → exists = \(exists)")
            guard exists else {
                applyState = .error(
                    message: "Resume file disappeared before submission. Please attach it again."
                )
                return
            }
        }

        let userId = user.uid

        Task {
            do {
                applyState = .checkingDuplicate
                let alreadyApplied = try await Self.withTimeout(seconds: Self.applyTimeout) {
                    try await applyService.hasExistingApplication(
                        jobId: job.id, userId: userId
                    )
                }
                if alreadyApplied {
                    applyState = .error(message: "You have already applied to this position.")
                    return
                }

                applyState = .submitting
                print("[ApplyFormView] Submitting application with resumeURL: \(resumeToUse)")
                _ = try await Self.withTimeout(seconds: Self.applyTimeout) {
                    try await applyService.submitApplication(
                        jobId: job.id,
                        jobTitle: job.title,
                        companyName: job.companyName,
                        userId: userId,
                        resumeURL: resumeToUse,
                        jobListingURL: nil,
                        isEasyApply: false,
                        coverNote: nil
                    )
                }

                // Submission succeeded — transition UI: submitted → success → auto-dismiss
                print("[ApplyFormView] ✅ Application submitted successfully.")
                applyState = .submitted
                AppState.shared.incrementJobsApplied()

                try? await Task.sleep(for: .seconds(1.2))
                applyState = .success

                try? await Task.sleep(for: .seconds(1.5))
                dismiss()
            } catch is CancellationError {
                // Task was cancelled (e.g. during auto-dismiss) — leave current state
                print("[ApplyFormView] Task cancelled, leaving current applyState.")
            } catch {
                print("[ApplyFormView] ❌ Submission failed: \(error.localizedDescription)")
                applyState = .error(message: error.localizedDescription)
            }
        }
    }

    // MARK: - Timeout Helper

    private static func withTimeout<T>(seconds: Duration, operation: @Sendable @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: seconds)
                throw ApplyError.custom(message: "Network Timeout – Try Again")
            }
            guard let result = try await group.next() else {
                group.cancelAll()
                throw ApplyError.custom(message: "Network Timeout – Try Again")
            }
            group.cancelAll()
            return result
        }
    }
}
