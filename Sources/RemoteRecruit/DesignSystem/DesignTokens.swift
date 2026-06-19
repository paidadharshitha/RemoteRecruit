// DesignTokens.swift
// RemoteRecruit

import SwiftUI

// MARK: - Design Tokens

/// Centralized design system constants used across the entire app.
/// Import this file wherever consistent styling is needed.
public enum DesignTokens {

    // MARK: - Spacing

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 24
        public static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radii

    public enum CornerRadius {
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let capsule: CGFloat = .infinity
    }

    // MARK: - Shadows

    public enum Shadow {
        public static let card = Color.black.opacity(0.06)
        public static let elevated = Color.black.opacity(0.1)
        public static let cardRadius: CGFloat = 6
        public static let elevatedRadius: CGFloat = 10

        public static func card(offsetY: CGFloat = 2) -> some View {
            Color.clear.shadow(color: card, radius: cardRadius, y: offsetY)
        }

        public static func elevated(offsetY: CGFloat = 4) -> some View {
            Color.clear.shadow(color: elevated, radius: elevatedRadius, y: offsetY)
        }
    }

    // MARK: - Semantic Colors

    public enum Colors {
        // Accent
        public static let accent = Color.blue
        public static let accentLight = Color.blue.opacity(0.12)

        // Status
        public static let success = Color.green
        public static let warning = Color.orange
        public static let error = Color.red
        public static let info = Color.indigo

        // Surface
        #if os(iOS)
        public static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        public static let surfaceElevated = Color(uiColor: .tertiarySystemGroupedBackground)
        public static let background = Color(uiColor: .systemGroupedBackground)
        #else
        public static let surface = Color(NSColor.controlBackgroundColor)
        public static let surfaceElevated = Color(NSColor.underPageBackgroundColor)
        public static let background = Color(NSColor.windowBackgroundColor)
        #endif

        // Glass
        public static let glassFill = Color.white.opacity(0.65)
        public static let glassBorder = Color.white.opacity(0.3)
    }

    // MARK: - Animations

    public enum Animations {
        public static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
        public static let springBouncy = SwiftUI.Animation.spring(response: 0.45, dampingFraction: 0.65)
        public static let quickSpring = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.85)
        public static let fade = SwiftUI.Animation.easeInOut(duration: 0.25)
        public static let slideUp = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.82, blendDuration: 0.15)
    }

    // MARK: - Typography

    public enum Typography {
        public static let title = SwiftUI.Font.title2.bold()
        public static let headline = SwiftUI.Font.headline
        public static let subheadline = SwiftUI.Font.subheadline
        public static let body = SwiftUI.Font.body
        public static let caption = SwiftUI.Font.caption
        public static let captionBold = SwiftUI.Font.caption.bold()
        public static let captionSemibold = SwiftUI.Font.caption.weight(.semibold)
        public static let caption2 = SwiftUI.Font.caption2
        public static let smallCaps = SwiftUI.Font.footnote.weight(.semibold)
    }
}
