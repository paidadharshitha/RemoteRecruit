// GlassCard.swift
// RemoteRecruit

import SwiftUI

// MARK: - Glass Card View Modifier

/// A reusable glassmorphism card modifier providing consistent styling.
/// Uses frosted glass background with subtle border and shadow.
public struct GlassCardModifier: ViewModifier {

    public let cornerRadius: CGFloat
    public let padding: CGFloat
    public let isElevated: Bool

    public init(
        cornerRadius: CGFloat = DesignTokens.CornerRadius.lg,
        padding: CGFloat = DesignTokens.Spacing.lg,
        isElevated: Bool = false
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.isElevated = isElevated
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DesignTokens.Colors.glassBorder, lineWidth: 0.5)
            )
            .shadow(
                color: isElevated ? DesignTokens.Shadow.elevated : DesignTokens.Shadow.card,
                radius: isElevated ? DesignTokens.Shadow.elevatedRadius : DesignTokens.Shadow.cardRadius,
                y: isElevated ? 4 : 2
            )
    }

    private var glassBackground: some View {
        #if os(iOS)
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial)
        #else
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DesignTokens.Colors.surface)
        #endif
    }
}

// MARK: - View Extension

extension View {

    /// Wraps content in a glassmorphism card with consistent styling.
    func glassCard(
        cornerRadius: CGFloat = DesignTokens.CornerRadius.lg,
        padding: CGFloat = DesignTokens.Spacing.lg,
        isElevated: Bool = false
    ) -> some View {
        modifier(GlassCardModifier(
            cornerRadius: cornerRadius,
            padding: padding,
            isElevated: isElevated
        ))
    }
}
