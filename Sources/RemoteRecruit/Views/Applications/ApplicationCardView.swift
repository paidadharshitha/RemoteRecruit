// ApplicationCardView.swift
// RemoteRecruit

import SwiftUI

// MARK: - Application Card View

/// A professional CRM-style card displaying a single tracked application
/// with status badge, sync actions, and manual check option.
struct ApplicationCardView: View {

    let application: JobApplication
    let isSyncing: Bool
    let onResync: () -> Void
    let onManualCheck: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header: Company avatar + Job title + Status badge
            HStack(alignment: .top, spacing: 12) {
                // Company Initial Avatar
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(application.companyInitial)
                            .font(.title3.bold())
                            .foregroundStyle(statusColor)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(application.jobTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(application.companyName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Status Badge
                statusBadge
            }
            .padding(.top, 14)
            .padding(.horizontal, 14)

            // Footer: Applied date + Sync status + Actions
            HStack(spacing: 0) {
                // Applied date
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(application.relativeAppliedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Sync status indicator
                syncStatusIndicator

                // Action buttons for stale/failed syncs
                if application.syncStatus.requiresAction {
                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 8)

                    Button(action: onResync) {
                        Label("Re-sync", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSyncing)

                    if isSyncing {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Button(action: onManualCheck) {
                            Label("Manual Check", systemImage: "safari")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
            .padding(.top, 8)
        }
#if os(iOS)
        .background(Color(uiColor: .systemBackground))
#else
        .background(Color(NSColor.windowBackgroundColor))
#endif
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(statusColor.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: application.status.iconName)
                .font(.caption2.weight(.semibold))
            Text(application.status.shortTag)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            statusColor.opacity(0.12),
            in: Capsule()
        )
    }

    // MARK: - Sync Status Indicator

    @ViewBuilder
    private var syncStatusIndicator: some View {
        HStack(spacing: 3) {
            Image(systemName: application.syncStatus.iconName)
                .font(.caption2)
                .foregroundStyle(syncColor)
            Text(application.relativeSyncDate)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Colors

    private var statusColor: Color {
        switch application.status {
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
