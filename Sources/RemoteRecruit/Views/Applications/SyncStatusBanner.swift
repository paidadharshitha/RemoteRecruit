// SyncStatusBanner.swift
// RemoteRecruit

import SwiftUI

// MARK: - Sync Status Banner

/// Displays an informational banner when one or more applications have stale or failed syncs.
/// Provides a quick action to batch re-sync all applications.
struct SyncStatusBanner: View {

    let needsAttentionCount: Int
    let onSyncAll: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                let pluralSuffix = needsAttentionCount == 1 ? "" : "s"
                Text("\(needsAttentionCount) application\(pluralSuffix) need attention")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text("Some statuses may be outdated. Tap to re-sync now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onSyncAll) {
                Text("Re-sync")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.yellow, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(.yellow).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.yellow).opacity(0.2), lineWidth: 1)
        )
    }
}
