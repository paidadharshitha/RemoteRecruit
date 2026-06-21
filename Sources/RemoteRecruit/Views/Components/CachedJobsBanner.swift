// CachedJobsBanner.swift
// RemoteRecruit

import SwiftUI

public struct CachedJobsBanner: View {
    public init() {}

    public var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "wifi.slash")
                .font(.caption2.weight(.semibold))
            Text("Showing Cached Jobs")
                .font(DesignTokens.Typography.captionSemibold)
            Spacer()
        }
        .foregroundStyle(DesignTokens.Colors.warning)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
        .padding(.horizontal, 20)
    }
}
