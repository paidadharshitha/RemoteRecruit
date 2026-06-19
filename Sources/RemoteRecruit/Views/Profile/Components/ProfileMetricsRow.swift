//
//  ProfileMetricsRow.swift
//  RemoteRecruit
//
//  Side-by-side metric cards for ATS Score and Jobs Applied.
//

import SwiftUI

// MARK: - ProfileMetricsRow

/// Displays two metric cards in a row: ATS Score and Jobs Applied count.
public struct ProfileMetricsRow: View {

    // MARK: Properties

    private let jobsAppliedCount: Int
    private let atsScore: Int

    // MARK: Initializer

    public init(jobsAppliedCount: Int, atsScore: Int) {
        self.jobsAppliedCount = jobsAppliedCount
        self.atsScore = atsScore
    }

    // MARK: Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.semibold))
.foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                Text("Metrics")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.bottom, 12)

            HStack(spacing: 12) {
                // ATS Score card
                metricCard(
                    icon: "doc.text.magnifyingglass",
                    value: "\(atsScore)",
                    label: "ATS Score",
                    gradientStart: Color.blue,
                    gradientEnd: Color.cyan
                )

                // Jobs Applied card
                metricCard(
                    icon: "paperplane.fill",
                    value: "\(jobsAppliedCount)",
                    label: "Jobs Applied",
                    gradientStart: Color.green,
                    gradientEnd: Color.mint
                )
            }
        }
        .padding(16)
        .background(PlatformColors.systemBackground, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }

    // MARK: Helpers

    private func metricCard(
        icon: String,
        value: String,
        label: String,
        gradientStart: Color,
        gradientEnd: Color
    ) -> some View {
        VStack(spacing: 8) {
            // Icon
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [gradientStart, gradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Value
            Text(value)
                .font(.title.bold())
                .foregroundStyle(.primary)

            // Label
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(PlatformColors.secondarySystemBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}
