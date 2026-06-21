// JobRow.swift
// RemoteRecruit

import SwiftUI

// MARK: - Job Row

/// A compact, professional row displaying essential job details.
/// Used in the job list for a clean, scannable layout.
struct JobRow: View {

    let job: Job
    var isSaved: Bool = false
    var onToggleSave: (() -> Void)?
    var onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { onTap?() }) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    // Title
                    Text(job.title)
                        .font(DesignTokens.Typography.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Company
                    Text(job.companyName)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    // Location + Salary
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Label(job.location, systemImage: "mappin.and.ellipse")
                            .font(DesignTokens.Typography.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()

                        if !job.salaryRange.isEmpty {
                            Text(job.salaryRange)
                                .font(DesignTokens.Typography.caption2.weight(.medium))
                                .foregroundStyle(DesignTokens.Colors.accent)
                                .lineLimit(1)
                        }
                    }

                    // Posted date + experience level
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Text(job.postedDate.relativeShort)
                            .font(DesignTokens.Typography.caption2)
                            .foregroundStyle(.tertiary)

                        Text("·")
                            .foregroundStyle(.quaternary)

                        Text(job.experienceLevel.displayName)
                            .font(DesignTokens.Typography.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                onToggleSave?()
            } label: {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.subheadline)
                    .foregroundStyle(isSaved ? DesignTokens.Colors.accent : .secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .padding(.trailing, DesignTokens.Spacing.md)
        }
    }
}
