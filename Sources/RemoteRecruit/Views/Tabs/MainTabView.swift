// MainTabView.swift
// RemoteRecruit

import SwiftUI

/// Root tab navigation shell with glassmorphism tab bar.
/// Replaces default SwiftUI TabView with a custom glass-styled bar.
public struct MainTabView: View {

    @StateObject private var appState = AppState.shared
    private let container: DIContainer

    @State private var selectedTab: String = "jobs"

    public init(container: DIContainer) {
        self.container = container
    }

    public var body: some View {
        GlassTabBarContainer(selectedTab: $selectedTab, tabs: tabItems) { tabId in
            switch tabId {
            case "jobs":
                NavigationStack {
                    JobListView(viewModel: container.makeJobListViewModel())
                }
            case "resume":
                NavigationStack {
                    ResumeOptimizerView(viewModel: container.makeResumeOptimizerViewModel())
                }
            case "applications":
                ApplicationsListView(viewModel: container.makeApplicationTrackerViewModel())
            case "profile":
                NavigationStack {
                    ProfileView()
                }
            default:
                NavigationStack {
                    JobListView(viewModel: container.makeJobListViewModel())
                }
            }
        }
        .tint(DesignTokens.Colors.accent)
    }

    // MARK: - Tab Items

    private var tabItems: [GlassTabItem] {
        [
            GlassTabItem(id: "jobs", icon: "briefcase.fill", title: "Jobs"),
            GlassTabItem(id: "resume", icon: "doc.text.badge.sparkles", title: "Resume AI"),
            GlassTabItem(id: "applications", icon: "clipboard.list", title: "Applied",
                         badgeCount: appState.jobsAppliedCount > 0 ? appState.jobsAppliedCount : nil),
            GlassTabItem(id: "profile", icon: "person.fill", title: "Profile")
        ]
    }
}
