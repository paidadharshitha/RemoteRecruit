// ApplicationDetailView.swift
// RemoteRecruit

import SwiftUI

// MARK: - Application Detail View

/// A detailed view for a single tracked job application.
/// Shows status timeline, sync information, and available actions.
/// Navigated to via NavigationLink from ApplicationsListView.
struct ApplicationDetailView: View {

    #if os(iOS)
    private static let inactiveFillColor = Color(uiColor: .systemFill)
    #else
    private static let inactiveFillColor = Color(NSColor.controlBackgroundColor)
    #endif

    // MARK: - Dependencies

    let application: JobApplication
    @ObservedObject var viewModel: ApplicationTrackerViewModel

    // MARK: - State

    @State private var isSyncing = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header card
                headerCard

                // Status timeline
                statusTimelineSection

                // Sync information
                syncInfoSection

                // Actions
                if application.syncStatus.requiresAction {
                    actionSection
                }
            }
            .padding()
        }
        .navigationTitle("Application Details")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Text(application.companyInitial)
                            .font(.title.bold())
                            .foregroundStyle(statusColor)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(application.jobTitle)
                        .font(.headline)
                    Text(application.companyName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Status badge (prominent)
            HStack(spacing: 8) {
                Image(systemName: application.status.iconName)
                    .font(.subheadline.weight(.semibold))
                Text(application.status.displayName)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(statusColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(statusColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(statusColor.opacity(0.15), lineWidth: 1)
            )

            Divider()

            // Applied date
            detailRow(
                icon: "calendar",
                color: .blue,
                title: "Applied",
                value: formattedDate(application.timestamp)
            )
        }
        .padding(16)
#if os(iOS)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 16))
#else
        .background(Color(NSColor.windowBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
#endif
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    // MARK: - Status Timeline

    private var statusTimelineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Application Timeline")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                timelineEntry(
                    status: .applied,
                    icon: "paperplane.fill",
                    title: "Applied",
                    subtitle: "Your application was submitted",
                    isCompleted: true,
                    isCurrent: application.status == .applied
                )

                timelineConnector(isActive: application.status.sortPriority <= 1)

                timelineEntry(
                    status: .inReview,
                    icon: "clock.fill",
                    title: "In Review",
                    subtitle: "Your application is being reviewed by the team",
                    isCompleted: application.status.sortPriority <= 1,
                    isCurrent: application.status == .inReview
                )

                timelineConnector(isActive: application.status.sortPriority == 0)

                timelineEntry(
                    status: .shortlisted,
                    icon: "star.fill",
                    title: "Shortlisted",
                    subtitle: "Congratulations! You've been shortlisted",
                    isCompleted: application.status == .shortlisted,
                    isCurrent: application.status == .shortlisted
                )
            }
            .padding(16)
#if os(iOS)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
#else
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
#endif
        }
    }

    // MARK: - Timeline Entry

    private func timelineEntry(
        status: ApplicationStatus,
        icon: String,
        title: String,
        subtitle: String,
        isCompleted: Bool,
        isCurrent: Bool
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isCompleted ? statusColor(for: status) : Self.inactiveFillColor)
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isCompleted ? .white : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isCompleted ? .primary : .secondary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(statusColor(for: status))
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Timeline Connector

    private func timelineConnector(isActive: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 12)
            Rectangle()
                .fill(isActive ? statusColor.opacity(0.3) : Self.inactiveFillColor)
                .frame(width: 2, height: 16)
            Spacer()
                .frame(height: 4)
        }
        .frame(width: 36)
    }

    // MARK: - Sync Info Section

    private var syncInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sync Information")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 12) {
                detailRow(
                    icon: application.syncStatus.iconName,
                    color: syncColor,
                    title: "Sync Status",
                    value: application.syncStatus.displayName
                )

                detailRow(
                    icon: "clock.arrow.circlepath",
                    color: .secondary,
                    title: "Last Synced",
                    value: application.relativeSyncDate
                )

                if let url = viewModel.manualCheckURL(for: application.jobId) {
                    Button {
                        if let link = URL(string: url) {
                            #if os(iOS)
                            UIApplication.shared.open(link)
                            #else
                            NSWorkspace.shared.open(link)
                            #endif
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "safari")
                                .font(.subheadline.weight(.semibold))
                            Text("Check Original Listing")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
#if os(iOS)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
#else
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
#endif
        }
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Actions")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.resyncApplication(application) }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.syncingApplicationId == application.id {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text("Re-sync")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.syncingApplicationId == application.id)
            }
        }
    }

    // MARK: - Helpers

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

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var statusColor: Color {
        statusColor(for: application.status)
    }

    private func statusColor(for status: ApplicationStatus) -> Color {
        switch status {
        case .applied: return .blue
        case .inReview: return .orange
        case .shortlisted: return .green
        case .rejected: return .red
        }
    }

    private var syncColor: Color {
        switch application.syncStatus {
        case .synced: return .green
        case .stale: return .yellow
        case .syncFailed: return .red
        case .needsManualCheck: return .orange
        }
    }
}
