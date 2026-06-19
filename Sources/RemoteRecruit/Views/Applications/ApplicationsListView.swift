// ApplicationsListView.swift
// RemoteRecruit

import SwiftUI
import FirebaseAuth

// MARK: - Applications List View

public struct ApplicationsListView: View {

    @StateObject private var viewModel: ApplicationTrackerViewModel
    @StateObject private var appState = AppState.shared
    @StateObject private var authService = AuthService.shared

    public init(viewModel: ApplicationTrackerViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.viewState {
                case .idle:
                    LoadingStateView(message: "Loading applications…")
                        .onAppear {
                            if let uid = authService.user?.uid {
                                Task { await viewModel.loadApplications(userId: uid) }
                            }
                        }

                case .loading:
                    LoadingStateView(message: "Fetching your applications…")

                case .success(let applications):
                    applicationsContent(applications: applications)

                case .empty:
                    EmptyStateView(
                        systemImage: "doc.text.magnifyingglass",
                        title: "No applications yet",
                        message: "Browse jobs and tap \"Apply\" to start tracking your applications here."
                    )

                case .error(let message):
                    ErrorStateView(message: message) {
                        if let uid = authService.user?.uid {
                            Task { await viewModel.refresh(userId: uid) }
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.viewState.isLoading)
            .navigationTitle("My Applications")
#if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let uid = authService.user?.uid {
                            Task { await viewModel.batchSync(userId: uid) }
                        }
                    } label: {
                        if viewModel.isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(viewModel.isSyncing)
                }
            }
#endif
            .refreshable {
                if let uid = authService.user?.uid {
                    await viewModel.refresh(userId: uid)
                }
            }
            .task {
                if let uid = authService.user?.uid {
                    if case .idle = viewModel.viewState {
                        await viewModel.loadApplications(userId: uid)
                    }
                }
            }
        }
    }

    // MARK: - Content

    private func applicationsContent(applications: [JobApplication]) -> some View {
        List {
            // Dashboard Header
            Section {
                ApplicationDashboardView(viewModel: viewModel)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            // Status Filter Pills
            Section {
                filterPills
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            // Needs Attention Banner
            if viewModel.needsAttentionCount > 0 {
                Section {
                    SyncStatusBanner(needsAttentionCount: viewModel.needsAttentionCount) {
                        if let uid = authService.user?.uid {
                            Task { await viewModel.batchSync(userId: uid) }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }

            // Application Rows
            Section {
                ForEach(applications) { application in
                    NavigationLink(value: application) {
                        ApplicationCardView(
                            application: application,
                            isSyncing: viewModel.syncingApplicationId == application.id,
                            onResync: {
                                Task { await viewModel.resyncApplication(application) }
                            },
                            onManualCheck: {
                                if let urlString = viewModel.manualCheckURL(for: application.jobId),
                                   let url = URL(string: urlString) {
                                    openURL(url)
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
        .navigationDestination(for: JobApplication.self) { application in
            ApplicationDetailView(application: application, viewModel: viewModel)
        }
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(
                    label: "All",
                    count: viewModel.totalCount,
                    isActive: viewModel.activeStatusFilter == nil,
                    action: { withAnimation(.easeInOut(duration: 0.2)) { viewModel.setFilter(nil) } }
                )

                ForEach(ApplicationStatus.allCases, id: \.rawValue) { status in
                    FilterPill(
                        label: status.displayName,
                        count: viewModel.count(for: status),
                        isActive: viewModel.activeStatusFilter == status,
                        action: { withAnimation(.easeInOut(duration: 0.2)) { viewModel.setFilter(status) } }
                    )
                }
            }
        }
    }
}

// MARK: - Filter Pill

private struct FilterPill: View {

    #if os(iOS)
    private static let inactiveBadgeColor = Color(uiColor: .tertiarySystemFill)
    #else
    private static let inactiveBadgeColor = Color(NSColor.quaternaryLabelColor)
    #endif

    let label: String
    let count: Int
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isActive ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            isActive ? Color.white.opacity(0.3) : Self.inactiveBadgeColor,
                            in: Capsule()
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                .pillBackground(isActive: isActive),
                in: Capsule()
            )
            .foregroundStyle(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Style helpers

private extension ShapeStyle where Self == Color {
    static func pillBackground(isActive: Bool) -> Color {
        #if os(iOS)
        isActive ? Color.blue : Color(uiColor: .secondarySystemFill)
        #else
        isActive ? Color.blue : Color(NSColor.controlBackgroundColor)
        #endif
    }
}

// MARK: - Cross-platform URL opener

#if os(iOS)
private func openURL(_ url: URL) {
    UIApplication.shared.open(url)
}
#else
import AppKit
private func openURL(_ url: URL) {
    NSWorkspace.shared.open(url)
}
#endif
