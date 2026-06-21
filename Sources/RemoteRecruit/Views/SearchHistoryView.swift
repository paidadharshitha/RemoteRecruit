// SearchHistoryView.swift
// RemoteRecruit

import SwiftUI

// MARK: - Search History View

/// Displays recent search queries as tappable chips below the search bar.
public struct SearchHistoryView: View {

    @ObservedObject var viewModel: SearchViewModel

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("Recent Searches")
                    .font(DesignTokens.Typography.captionSemibold)
                    .foregroundStyle(.secondary)

                Spacer()

                if !viewModel.recentSearches.isEmpty {
                    Button(role: .destructive) {
                        withAnimation(DesignTokens.Animations.quickSpring) {
                            viewModel.clearHistory()
                        }
                    } label: {
                        Text("Clear")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.recentSearches.isEmpty {
                Text("No recent searches")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: DesignTokens.Spacing.sm) {
                    ForEach(viewModel.recentSearches, id: \.self) { query in
                        searchChip(query: query)
                    }
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
    }

    // MARK: - Search Chip

    private func searchChip(query: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text(query)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Button {
                withAnimation(DesignTokens.Animations.quickSpring) {
                    viewModel.removeRecentSearch(query)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            DesignTokens.Colors.surfaceElevated,
            in: Capsule()
        )
        .onTapGesture {
            viewModel.selectRecentSearch(query)
        }
    }
}
