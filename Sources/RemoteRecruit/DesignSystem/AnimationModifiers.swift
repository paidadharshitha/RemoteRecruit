// AnimationModifiers.swift
// RemoteRecruit

import SwiftUI

// MARK: - Animated Appearance Modifier

/// A reusable modifier that animates views appearing on screen
/// with a staggered fade + slide-up effect.
public struct AnimatedAppearanceModifier: ViewModifier {

    public let delay: Double
    public let yOffset: CGFloat

    @State private var isVisible = false

    public init(delay: Double = 0, yOffset: CGFloat = 12) {
        self.delay = delay
        self.yOffset = yOffset
    }

    public func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : yOffset)
            .onAppear {
                withAnimation(DesignTokens.Animations.spring.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Animated Tab Transition Modifier

/// Animates content changes when switching tabs with a cross-fade effect.
public struct TabTransitionModifier: ViewModifier {

    @Binding var isActive: Bool

    public func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0.6)
            .scaleEffect(isActive ? 1 : 0.95)
    }
}

// MARK: - Section Header Modifier

/// Consistent section header styling with icon badge.
public struct SectionHeaderModifier: ViewModifier {

    public let icon: String

    public func body(content: Content) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(DesignTokens.Typography.captionSemibold)
                .foregroundStyle(DesignTokens.Colors.accent)
                .frame(width: 28, height: 28)
                .background(DesignTokens.Colors.accentLight, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm))

            content
                .font(DesignTokens.Typography.subheadline.bold())
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.bottom, DesignTokens.Spacing.md)
    }
}

// MARK: - View Extensions

extension View {

    /// Applies a staggered fade + slide-up animation on appear.
    func animatedAppearance(delay: Double = 0, yOffset: CGFloat = 12) -> some View {
        modifier(AnimatedAppearanceModifier(delay: delay, yOffset: yOffset))
    }

    /// Applies tab transition (scale + opacity) based on active state.
    func tabTransition(isActive: Bool) -> some View {
        modifier(TabTransitionModifier(isActive: Binding(
            get: { isActive },
            set: { _ in }
        )))
    }

    /// Applies a consistent section header with icon badge.
    func sectionHeader(icon: String) -> some View {
        modifier(SectionHeaderModifier(icon: icon))
    }

    /// Applies a conditional visibility animation with spring.
    func conditionalAnimation<Value: Equatable>(_ value: Value) -> some View {
        animation(DesignTokens.Animations.spring, value: value)
    }
}
