// StateViews.swift
// RemoteRecruit

import SwiftUI

// MARK: - Empty State View

public struct EmptyStateView: View {

    public let systemImage: String
    public let title: String
    public let message: String

    public var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            Image(systemName: systemImage)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                    .font(DesignTokens.Typography.title)

                Text(message)
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animatedAppearance()
    }
}

// MARK: - Error State View

public struct ErrorStateView: View {

    public let message: String
    public let retryAction: () -> Void

    public var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(DesignTokens.Colors.warning)

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Something went wrong")
                    .font(DesignTokens.Typography.title)

                Text(message)
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                retryAction()
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(DesignTokens.Typography.captionSemibold)
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.accent, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DesignTokens.Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animatedAppearance()
    }
}

// MARK: - Loading State View

public struct LoadingStateView: View {

    public let message: String

    public var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(DesignTokens.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animatedAppearance()
    }
}
