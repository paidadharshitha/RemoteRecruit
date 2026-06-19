// JobDetailView.swift
// RemoteRecruit

import SwiftUI
@preconcurrency import FirebaseAuth
#if canImport(UIKit)
import UIKit
#endif

struct JobDetailView: View {

    let job: Job
    let applyService: ApplyServiceProtocol

    @StateObject private var appState = AppState.shared
    @State private var applyState: ApplyState = .idle
    @State private var showOptimizer = false
    @State private var showApplyForm = false
    @State private var isDescriptionExpanded = false

    init(job: Job, applyService: ApplyServiceProtocol = DIContainer.shared.applyService) {
        self.job = job
        self.applyService = applyService
    }

    // MARK: - Relative Date Formatting

    private var postedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: job.postedDate, relativeTo: Date())
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header with tags directly under title
                headerSection

                // Metadata card (no tags here — moved to header)
                metadataCard

                // Job Description — primary content
                descriptionSection

                // Action Buttons — Optimize is primary, Apply is secondary
                actionButtonsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle(job.title)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
#if os(iOS)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // TODO: Implement share functionality
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
#endif
#if os(iOS)
        .fullScreenCover(isPresented: $showApplyForm) {
            ApplyFormView(job: job, applyService: applyService)
        }
#else
        .sheet(isPresented: $showApplyForm) {
            ApplyFormView(job: job, applyService: applyService)
        }
#endif
    }

    // MARK: - Header Section (Title + Posted + Tags Pills)

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Company avatar + name
            HStack(spacing: 12) {
                Circle()
                    .fill(.tint.opacity(0.12))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(String(job.companyName.prefix(1)))
                            .font(.title2.bold())
                            .foregroundStyle(.tint)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(job.companyName)
                        .font(.title3.bold())
                    Text(job.location)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Job Title
            Text(job.title)
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)

            // Posted date row
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Posted \(postedText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Consolidated tags as pills
            if !job.tags.isEmpty {
                TagPillsView(tags: job.tags)
            }

            Divider()
        }
    }

    // MARK: - Metadata Card

    private var metadataCard: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            detailRow(icon: "banknote", color: .green, title: "Salary Range", value: job.salaryRange)
            detailRow(icon: "mappin", color: .blue, title: "Location", value: job.location)
            detailRow(icon: "wifi", color: .indigo, title: "Work Type", value: "Fully Remote")
            detailRow(icon: "briefcase", color: .orange, title: "Experience", value: job.experienceLevel.displayName)
        }
        .glassCard(cornerRadius: DesignTokens.CornerRadius.lg)
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            sectionLabel("Job Description")

            Text(job.jobDescription)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(.primary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .glassCard(cornerRadius: DesignTokens.CornerRadius.lg)
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        VStack(spacing: 14) {
            // Primary: Optimize Resume
            optimizeResumeButton

            // Secondary: Apply Now (single instance, no floating duplicate)
            switch applyState {
            case .idle:
                applyButton

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
                    Button("Try Again") {
                        applyState = .idle
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .padding(12)
                .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    // MARK: - Optimize Resume Button (Primary)

    private var optimizeResumeButton: some View {
        Button {
            showOptimizer = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                Text("Optimize Resume for This Job")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                LinearGradient(
                    colors: [.indigo, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .shadow(color: .indigo.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Apply Now Button (Secondary — single instance)

    private var applyButton: some View {
        Button {
            showApplyForm = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "paperplane.fill")
                Text("Apply Now")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Apply Action

    private static let applyTimeout: Duration = .seconds(5)

    private func handleApply() {
        guard let user = AuthService.shared.user, !user.uid.isEmpty else {
            applyState = .error(message: "Please sign in to apply.")
            return
        }

        // Check if user has an optimized resume
        let resumeURL = "" // TODO: Fetch from user profile's optimized resume URL
        guard !resumeURL.isEmpty else {
            applyState = .error(message: "Please upload and optimize your resume in the AI Optimizer tab first.")
            return
        }

        Task {
            do {
                // Check for duplicate (with timeout)
                applyState = .checkingDuplicate
                let alreadyApplied = try await Self.withTimeout(seconds: Self.applyTimeout) {
                    try await applyService.hasExistingApplication(
                        jobId: job.id, userId: user.uid
                    )
                }
                if alreadyApplied {
                    applyState = .error(message: "You have already applied to this position.")
                    return
                }

                // Submit application (with timeout)
                applyState = .submitting
                _ = try await Self.withTimeout(seconds: Self.applyTimeout) {
                    try await applyService.submitApplication(
                        jobId: job.id,
                        jobTitle: job.title,
                        companyName: job.companyName,
                        userId: user.uid,
                        resumeURL: resumeURL,
                        jobListingURL: nil,
                        isEasyApply: false,
                        coverNote: nil
                    )
                }

                applyState = .submitted
                appState.incrementJobsApplied()

                // Transition to full success after a brief delay
                try? await Task.sleep(for: .seconds(1.2))
                applyState = .success
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

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func detailRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
            }

            Spacer()
        }
    }
}

// MARK: - Tag Pills View

private struct TagPillsView: View {

    let tags: [String]

    var body: some View {
        FlowLayoutView(items: tags) { tag in
            Text(tag)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(.tint.opacity(0.08))
                )
                .foregroundStyle(.tint.opacity(0.85))
        }
    }
}

// MARK: - Simple Flow Layout

private struct FlowLayoutView<Item: Hashable, Content: View>: View {

    let items: [Item]
    let content: (Item) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        VStack {
            GeometryReader { geo in
                SelfSizingLayout(
                    items: items,
                    content: content,
                    containerWidth: geo.size.width,
                    heightBinding: $totalHeight
                )
            }
            .frame(height: totalHeight)
        }
    }
}

private struct SelfSizingLayout<Item: Hashable, Content: View>: View {

    let items: [Item]
    let content: (Item) -> Content
    let containerWidth: CGFloat
    @Binding var heightBinding: CGFloat

    init(
        items: [Item],
        content: @escaping (Item) -> Content,
        containerWidth: CGFloat,
        heightBinding: Binding<CGFloat>
    ) {
        self.items = items
        self.content = content
        self.containerWidth = containerWidth
        self._heightBinding = heightBinding
    }

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > containerWidth {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        width = -d.width
                        return result
                    }
                    .alignmentGuide(.top) { d in
                        if abs(width - d.width) > containerWidth {
                            width = 0
                            height -= d.height
                        }
                        let result = height
                        if width <= 0 {
                            height = -d.height
                        }
                        return result
                    }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { h in
            heightBinding = h
        }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
