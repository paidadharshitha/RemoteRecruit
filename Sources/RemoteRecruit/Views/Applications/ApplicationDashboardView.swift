// ApplicationDashboardView.swift
// RemoteRecruit

import SwiftUI

// MARK: - Application Dashboard View

/// A professional summary dashboard showing application counts by status.
/// Designed as a CRM-style header card for the Applications tab.
struct ApplicationDashboardView: View {

    #if os(iOS)
    private static let ringTrackColor = Color(uiColor: .systemFill)
    #else
    private static let ringTrackColor = Color(NSColor.controlBackgroundColor)
    #endif

    @ObservedObject var viewModel: ApplicationTrackerViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Total Applications Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Applications")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.totalCount)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer()

                // Total applications ring indicator
                ZStack {
                    Circle()
                        .stroke(Self.ringTrackColor, lineWidth: 4)
                        .frame(width: 48, height: 48)

                    Circle()
                        .trim(from: 0, to: min(CGFloat(viewModel.totalCount) / 50.0, 1.0))
                        .stroke(.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))

                    Text("\(viewModel.totalCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Status Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                StatusMetricCard(
                    label: "Applied",
                    count: viewModel.count(for: .applied),
                    icon: "paperplane.fill",
                    color: .blue
                )

                StatusMetricCard(
                    label: "In Review",
                    count: viewModel.count(for: .inReview),
                    icon: "clock.fill",
                    color: .orange
                )

                StatusMetricCard(
                    label: "Shortlisted",
                    count: viewModel.count(for: .shortlisted),
                    icon: "star.fill",
                    color: .green
                )

                StatusMetricCard(
                    label: "Rejected",
                    count: viewModel.count(for: .rejected),
                    icon: "xmark.circle.fill",
                    color: .red
                )
            }
        }
        .padding(16)
#if os(iOS)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16))
#else
        .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
#endif
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}

// MARK: - Status Metric Card

private struct StatusMetricCard: View {

    let label: String
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text("\(count)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(color.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
}
