// GlassTabBar.swift
// RemoteRecruit

import SwiftUI

// MARK: - Tab Item

/// Represents a single tab in the glassmorphism tab bar.
public struct GlassTabItem: Identifiable {
    public let id: String
    public let icon: String
    public let title: String
    public let badgeCount: Int?

    public init(id: String, icon: String, title: String, badgeCount: Int? = nil) {
        self.id = id
        self.icon = icon
        self.title = title
        self.badgeCount = badgeCount
    }
}

// MARK: - Glass Tab Bar

/// A custom glassmorphism tab bar with animated selection indicator.
/// Uses frosted glass material with a sliding pill indicator.
public struct GlassTabBar: View {

    @Binding var selectedTab: String
    let tabs: [GlassTabItem]
    let onTabChange: (String) -> Void

    @Namespace private var selectionNamespace

    public init(
        selectedTab: Binding<String>,
        tabs: [GlassTabItem],
        onTabChange: @escaping (String) -> Void = { _ in }
    ) {
        self._selectedTab = selectedTab
        self.tabs = tabs
        self.onTabChange = onTabChange
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                tabButton(tab: tab)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        #if os(iOS)
        .background(.ultraThinMaterial)
        #else
        .background(DesignTokens.Colors.surface.opacity(0.9))
        #endif
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(DesignTokens.Colors.glassBorder, lineWidth: 0.5)
        )
        .shadow(color: DesignTokens.Shadow.elevated, radius: DesignTokens.Shadow.elevatedRadius, y: 2)
    }

    // MARK: - Tab Button

    private func tabButton(tab: GlassTabItem) -> some View {
        Button {
            withAnimation(DesignTokens.Animations.spring) {
                selectedTab = tab.id
            }
            onTabChange(tab.id)
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                ZStack {
                    // Selection pill background
                    if selectedTab == tab.id {
                        Capsule()
                            .fill(DesignTokens.Colors.accent)
                            .frame(height: 36)
                            .matchedGeometryEffect(id: "tab_\(tab.id)", in: selectionNamespace)
                            .transition(.opacity)
                    }

                    Label(tab.title, systemImage: tab.icon)
                        .font(DesignTokens.Typography.captionSemibold)
                        .foregroundStyle(selectedTab == tab.id ? .white : .secondary)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .frame(height: 36)
                }

                // Badge
                if let count = tab.badgeCount, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(DesignTokens.Colors.error, in: Circle())
                        .offset(x: -4, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Tab Bar Container View

/// A full-width glassmorphism tab bar positioned at the bottom of the screen.
/// Designed to replace the default SwiftUI TabView bar.
public struct GlassTabBarContainer<Content: View>: View {

    @Binding var selectedTab: String
    let tabs: [GlassTabItem]
    let content: (String) -> Content
    let onTabChange: (String) -> Void

    public init(
        selectedTab: Binding<String>,
        tabs: [GlassTabItem],
        @ViewBuilder content: @escaping (String) -> Content,
        onTabChange: @escaping (String) -> Void = { _ in }
    ) {
        self._selectedTab = selectedTab
        self.tabs = tabs
        self.content = content
        self.onTabChange = onTabChange
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            content(selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Tab bar with safe area inset
            VStack(spacing: 0) {
                #if os(iOS)
                Divider().opacity(0.3)
                #endif
                GlassTabBar(selectedTab: $selectedTab, tabs: tabs, onTabChange: onTabChange)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                #if os(iOS)
                    .padding(.bottom, 8)
                #endif
            }
        }
    }
}
