// EasyApplyView.swift
// RemoteRecruit

import SwiftUI
@preconcurrency import FirebaseAuth

// MARK: - Easy Apply View

/// A streamlined one-tap apply view with optional cover note.
/// Integrates with the existing ApplyServiceProtocol.
public struct EasyApplyView: View {

    let job: Job
    let applyService: ApplyServiceProtocol

    @StateObject private var appState = AppState.shared
    @State private var applyState: ApplyState = .idle
    @State private var coverNote: String = ""
    @State private var showCoverNoteField = false

    @Environment(\.dismiss) private var dismiss

    public init(
        job: Job,
        applyService: ApplyServiceProtocol = DIContainer.shared.applyService
    ) {
        self.job = job
        self.applyService = applyService
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xl) {
                    // Job summary
                    jobSummaryCard
                        .animatedAppearance()

                    // Resume check
                    resumeStatusCard
                        .animatedAppearance(delay: 0.1)

                    // Cover note (optional)
                    if showCoverNoteField {
                        coverNoteCard
                            .animatedAppearance(delay: 0.2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Apply button
                    applyActionSection
                        .animatedAppearance(delay: 0.3)
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Colors.background)
            .navigationTitle("Easy Apply")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Job Summary Card

    private var jobSummaryCard: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Company avatar
            Circle()
                .fill(DesignTokens.Colors.accentLight)
                .frame(width: 48, height: 48)
                .overlay {
                    Text(String(job.companyName.prefix(1)))
                        .font(DesignTokens.Typography.title.bold())
                        .foregroundStyle(DesignTokens.Colors.accent)
                }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(job.title)
                    .font(DesignTokens.Typography.headline)
                    .lineLimit(1)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(job.companyName)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(job.location)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(job.salaryRange)
                    .font(DesignTokens.Typography.captionSemibold)
                    .foregroundStyle(DesignTokens.Colors.success)
            }

            Spacer()
        }
        .glassCard(cornerRadius: DesignTokens.CornerRadius.lg)
    }

    // MARK: - Resume Status Card

    private var resumeStatusCard: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Label("Resume", systemImage: "doc.text.fill")
                .font(DesignTokens.Typography.subheadline.bold())
                .sectionHeader(icon: "doc.text.fill")

            if appState.hasUploadedResume {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignTokens.Colors.success)
                    Text("Optimized resume ready")
                        .font(DesignTokens.Typography.body)
                }
            } else {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(DesignTokens.Colors.warning)
                    Text("Upload and optimize your resume first")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .glassCard(cornerRadius: DesignTokens.CornerRadius.lg)
    }

    // MARK: - Cover Note Card

    private var coverNoteCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Label("Cover Note (optional)", systemImage: "pencil.text")
                    .font(DesignTokens.Typography.subheadline.bold())

                Spacer()

                Button("Remove") {
                    withAnimation(DesignTokens.Animations.spring) {
                        showCoverNoteField = false
                        coverNote = ""
                    }
                }
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.secondary)
            }

            TextEditor(text: $coverNote)
                .font(DesignTokens.Typography.body)
                .frame(minHeight: 80, maxHeight: 140)
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .stroke(DesignTokens.Colors.glassBorder, lineWidth: 0.5)
                )
        }
        .glassCard(cornerRadius: DesignTokens.CornerRadius.lg)
    }

    // MARK: - Apply Action Section

    private var applyActionSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Add cover note toggle
            if !showCoverNoteField {
                Button {
                    withAnimation(DesignTokens.Animations.spring) {
                        showCoverNoteField = true
                    }
                } label: {
                    Label("Add a cover note", systemImage: "plus.bubble")
                        .font(DesignTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.accent)
                }
                .buttonStyle(.plain)
            }

            // Apply button
            switch applyState {
            case .idle:
                Button {
                    handleEasyApply()
                } label: {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "paperplane.fill")
                        Text("Easy Apply")
                            .font(DesignTokens.Typography.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    )
                    .shadow(color: .indigo.opacity(0.25), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(!appState.hasUploadedResume)

            case .checkingDuplicate:
                HStack(spacing: DesignTokens.Spacing.md) {
                    ProgressView()
                        .tint(.white)
                    Text("Checking…")
                        .font(DesignTokens.Typography.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(.indigo, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))

            case .submitting:
                HStack(spacing: DesignTokens.Spacing.md) {
                    ProgressView()
                        .tint(.white)
                    Text("Submitting…")
                        .font(DesignTokens.Typography.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(.indigo, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))

            case .submitted:
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("Submitted")
                        .font(DesignTokens.Typography.subheadline.weight(.semibold))
                }
                .foregroundStyle(DesignTokens.Colors.accent)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(DesignTokens.Colors.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))

            case .success:
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("Applied Successfully!")
                        .font(DesignTokens.Typography.subheadline.weight(.semibold))
                }
                .foregroundStyle(DesignTokens.Colors.success)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(DesignTokens.Colors.success.opacity(0.1), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))

            case .error(let message):
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.error)

                    Button("Try Again") {
                        applyState = .idle
                    }
                    .font(DesignTokens.Typography.captionSemibold)
                    .foregroundStyle(DesignTokens.Colors.accent)
                }
                .frame(maxWidth: .infinity, minHeight: 54)
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.error.opacity(0.06), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
            }
        }
    }

    // MARK: - Apply Action

    private static let applyTimeout: Duration = .seconds(5)

    private func handleEasyApply() {
        guard let user = AuthService.shared.user, !user.uid.isEmpty else {
            applyState = .error(message: "Please sign in to apply.")
            return
        }

        let resumeURL = "" // TODO: Fetch from user profile
        guard !resumeURL.isEmpty else {
            applyState = .error(message: "Please optimize your resume first.")
            return
        }

        Task {
            do {
                applyState = .checkingDuplicate
                let alreadyApplied = try await Self.withTimeout(seconds: Self.applyTimeout) {
                    try await applyService.hasExistingApplication(jobId: job.id, userId: user.uid)
                }
                if alreadyApplied {
                    applyState = .error(message: "You have already applied to this position.")
                    return
                }

                applyState = .submitting
                _ = try await Self.withTimeout(seconds: Self.applyTimeout) {
                    try await applyService.submitApplication(
                        jobId: job.id,
                        jobTitle: job.title,
                        companyName: job.companyName,
                        userId: user.uid,
                        resumeURL: resumeURL,
                        jobListingURL: nil,
                        isEasyApply: true,
                        coverNote: coverNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : coverNote
                    )
                }

                applyState = .submitted
                appState.incrementJobsApplied()

                // Transition to full success after a brief delay
                try? await Task.sleep(for: .seconds(1.2))
                applyState = .success

                // Auto-dismiss after success
                try? await Task.sleep(for: .seconds(1.5))
                dismiss()
            } catch {
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
