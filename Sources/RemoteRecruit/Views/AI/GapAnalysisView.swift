// GapAnalysisView.swift
// RemoteRecruit

import SwiftUI

// MARK: - Gap Analysis View

/// Displays a visual comparison between the user's skills and a job's requirements.
/// Shows a circular match score, matched skills in green, and missing skills in red.
public struct GapAnalysisView: View {

    let job: Job
    let userSkills: [String]

    @StateObject private var viewModel: GapAnalysisViewModel
    @Environment(\.dismiss) private var dismiss

    public init(job: Job, userSkills: [String]) {
        self.job = job
        self.userSkills = userSkills
        _viewModel = StateObject(wrappedValue: GapAnalysisViewModel(userSkills: userSkills, job: job))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xxl) {
                    // Score header
                    scoreHeader
                        .animatedAppearance()

                    // Matched skills
                    if let result = result, !result.matchedSkills.isEmpty {
                        skillSection(
                            title: "Matched Skills",
                            icon: "checkmark.circle.fill",
                            color: DesignTokens.Colors.success,
                            skills: result.matchedSkills
                        )
                        .animatedAppearance(delay: 0.15)
                    }

                    // Missing skills
                    if let result = result, !result.missingSkills.isEmpty {
                        skillSection(
                            title: "Skills to Build",
                            icon: "exclamationmark.triangle.fill",
                            color: DesignTokens.Colors.warning,
                            skills: result.missingSkills
                        )
                        .animatedAppearance(delay: 0.3)
                    }

                    // Suggestions
                    if let result = result {
                        suggestionsCard(for: result)
                            .animatedAppearance(delay: 0.45)
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Colors.background)
            .navigationTitle("Skill Gap Analysis")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.analyze()
            }
        }
    }

    // MARK: - Computed

    private var result: GapAnalysisResult? {
        if case .result(let r) = viewModel.state { return r }
        return nil
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(DesignTokens.Colors.surfaceElevated, lineWidth: 12)
                    .frame(width: 140, height: 140)

                // Score ring
                Circle()
                    .trim(from: 0, to: CGFloat(scoreFraction))
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(DesignTokens.Animations.springBouncy, value: scoreFraction)

                // Score text
                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text("\(scoreValue)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)

                    Text("Match")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(job.title)
                    .font(DesignTokens.Typography.headline)

                Text(job.companyName)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .glassCard(cornerRadius: DesignTokens.CornerRadius.xl, padding: DesignTokens.Spacing.xxl)
    }

    private var scoreValue: Int {
        result?.matchScore ?? 0
    }

    private var scoreFraction: Double {
        Double(scoreValue) / 100.0
    }

    private var scoreColor: Color {
        switch scoreValue {
        case 80...: return DesignTokens.Colors.success
        case 50..<80: return DesignTokens.Colors.warning
        default: return DesignTokens.Colors.error
        }
    }

    // MARK: - Skill Section

    private func skillSection(title: String, icon: String, color: Color, skills: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Label(title, systemImage: icon)
                .font(DesignTokens.Typography.subheadline.bold())
                .foregroundStyle(color)

            FlowLayout(spacing: DesignTokens.Spacing.sm) {
                ForEach(skills, id: \.self) { skill in
                    Text(skill)
                        .font(DesignTokens.Typography.caption.weight(.medium))
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(color.opacity(0.12), in: Capsule())
                        .foregroundStyle(color)
                }
            }
        }
        .glassCard(cornerRadius: DesignTokens.CornerRadius.lg)
    }

    // MARK: - Suggestions Card

    private func suggestionsCard(for result: GapAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Label("Recommendations", systemImage: "lightbulb.fill")
                .font(DesignTokens.Typography.subheadline.bold())
                .foregroundStyle(DesignTokens.Colors.info)

            if result.matchScore >= 80 {
                suggestionRow("Strong match! Consider applying with your current profile.")
            }
            if result.matchScore < 80 && !result.missingSkills.isEmpty {
                let top = Array(result.missingSkills.prefix(3)).joined(separator: ", ")
                suggestionRow("Focus on learning: \(top)")
            }
            if userSkills.isEmpty {
                suggestionRow("Add your skills to your profile for more accurate analysis.")
            }
            suggestionRow("Use the AI Resume Optimizer to tailor your resume for this role.")
        }
        .glassCard(cornerRadius: DesignTokens.CornerRadius.lg)
    }

    private func suggestionRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "arrow.right.circle.fill")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.info)
                .frame(width: 20)

            Text(text)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
}
