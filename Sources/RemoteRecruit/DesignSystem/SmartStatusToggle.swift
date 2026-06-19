// SmartStatusToggle.swift
// RemoteRecruit

import SwiftUI

// MARK: - Smart Status Toggle

/// A glassmorphism-styled segmented control for selecting an experience level.
/// Uses a sliding pill indicator via matchedGeometryEffect and shows contextual
/// descriptions for each status. This is the single source of truth — the
/// previous copy at Views/Profile/Components/SmartStatusToggle.swift was removed.
public struct SmartStatusToggle: View {

    @Binding var selection: ExperienceLevel
    var onSelectionChange: ((ExperienceLevel) -> Void)?

    @Namespace private var indicatorNamespace

    private var options: [(ExperienceLevel, String, String)] {
        [
            (.student, "Student", "graduationcap.fill"),
            (.fresher, "Fresher", "leaf.fill"),
            (.experienced, "Experienced", "briefcase.fill")
        ]
    }

    public init(
        selection: Binding<ExperienceLevel>,
        onSelectionChange: ((ExperienceLevel) -> Void)? = nil
    ) {
        self._selection = selection
        self.onSelectionChange = onSelectionChange
    }

    public var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Segmented toggle
            HStack(spacing: 0) {
                ForEach(options, id: \.0) { level, label, icon in
                    statusButton(level: level, label: label, icon: icon)
                }
            }
            .padding(DesignTokens.Spacing.xs)
            #if os(iOS)
            .background(.ultraThinMaterial)
            #else
            .background(DesignTokens.Colors.surfaceElevated)
            #endif
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(DesignTokens.Colors.glassBorder, lineWidth: 0.5)
            )

            // Description
            Text(selection.description)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .transition(.opacity)
                .animation(DesignTokens.Animations.fade, value: selection)
        }
    }

    // MARK: - Status Button

    private func statusButton(level: ExperienceLevel, label: String, icon: String) -> some View {
        Button {
            withAnimation(DesignTokens.Animations.springBouncy) {
                selection = level
            }
            onSelectionChange?(level)
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                ZStack {
                    // Sliding indicator pill
                    if selection == level {
                        Capsule()
                            .fill(DesignTokens.Colors.accent)
                            .matchedGeometryEffect(id: "status_indicator", in: indicatorNamespace)
                    }

                    Label(label, systemImage: icon)
                        .font(DesignTokens.Typography.captionSemibold)
                        .foregroundStyle(selection == level ? .white : .secondary)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Experience Level Extensions

extension ExperienceLevel {

    /// A short contextual description shown below the toggle.
    var description: String {
        switch self {
        case .student:
            return "Currently studying — looking for internships and co-op positions."
        case .fresher:
            return "Recent graduate — seeking entry-level and associate roles."
        case .experienced:
            return "Working professional — targeting senior and lead positions."
        }
    }
}

// MARK: - Animated Conditional Fields

/// A view modifier that animates conditional fields based on the experience level.
/// Fields slide in from bottom when appearing and slide out upward when disappearing.
public struct AnimatedConditionalFieldsModifier<ChildContent: View>: ViewModifier {

    let isActive: Bool
    let childContent: () -> ChildContent

    @State private var isVisible = false

    public init(isActive: Bool, @ViewBuilder content: @escaping () -> ChildContent) {
        self.isActive = isActive
        self.childContent = content
    }

    public func body(content: Content) -> some View {
        content
            .opacity(isActive && isVisible ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onChange(of: isActive) { _, newValue in
                withAnimation(DesignTokens.Animations.spring) {
                    isVisible = newValue
                }
            }
    }
}

// MARK: - View Extension

extension View {

    /// Wraps content that should appear/disappear based on a condition with animation.
    func animatedConditionalFields(isActive: Bool, @ViewBuilder content: @escaping () -> some View) -> some View {
        modifier(AnimatedConditionalFieldsModifier(isActive: isActive, content: content))
    }
}
