// JobListView.swift
// RemoteRecruit

import SwiftUI

// MARK: - Job List View

public struct JobListView: View {

    @StateObject private var viewModel: JobListViewModel
    @StateObject private var appState = AppState.shared
    @StateObject private var searchViewModel = SearchViewModel(historyService: DIContainer.shared.searchHistoryService)
    private let applyService: ApplyServiceProtocol

    @State private var selectedJob: Job?
    @State private var localPickerDomain: JobDomain?
    @State private var searchText: String = ""
    @State private var localExperienceFilter: ExperienceLevel?
    @FocusState private var isSearchFieldFocused: Bool

    public init(viewModel: JobListViewModel, applyService: ApplyServiceProtocol = DIContainer.shared.applyService) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.applyService = applyService
    }

    public var body: some View {
        Group {
            switch viewModel.viewState {
            case .idle:
                ProgressView("Loading jobs...")
                    .onAppear { Task { await viewModel.loadJobsWhenReady() } }

            case .loading:
                VStack(spacing: DesignTokens.Spacing.md) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Finding jobs for you...")
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }

            case .success(let jobs):
                jobListContent(jobs: jobs)

            case .empty:
                emptyStateContent

            case .error(let message):
                ErrorStateView(message: message) {
                    Task { await viewModel.refresh() }
                }
            }
        }
        .onChange(of: searchText) { _, _ in
            appState.searchText = searchText
            viewModel.applyFilter()
        }
        .onChange(of: localPickerDomain) {
            viewModel.domainPickerDidChange(localPickerDomain)
        }
        .onChange(of: localExperienceFilter) {
            viewModel.selectedExperienceFilter = localExperienceFilter
            viewModel.applyFilter()
        }
        .onChange(of: appState.profile) {
            viewModel.applyFilter()
        }
        .onChange(of: searchViewModel.isSearchFocused) { _, focused in
            if !focused {
                isSearchFieldFocused = false
            }
        }
        .onChange(of: searchViewModel.searchText) { _, newText in
            searchText = newText
        }
        .navigationTitle("RemoteRecruit")
        .task {
            if case .idle = viewModel.viewState {
                await viewModel.loadJobsWhenReady()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .navigationDestination(item: $selectedJob) { job in
            JobDetailView(job: job)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.subheadline.weight(.medium))

            TextField("Search jobs, companies, or skills...", text: $searchText)
                .font(DesignTokens.Typography.subheadline)
                .submitLabel(.search)
                .focused($isSearchFieldFocused)

            if !searchText.isEmpty {
                Button {
                    withAnimation(DesignTokens.Animations.quickSpring) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            DesignTokens.Colors.surfaceElevated,
            in: Capsule()
        )
    }

    // MARK: - Success: Job List

    private func jobListContent(jobs: [Job]) -> some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 20)
                .padding(.top, DesignTokens.Spacing.sm)

            if searchViewModel.isSearchFocused && !searchViewModel.recentSearches.isEmpty {
                SearchHistoryView(viewModel: searchViewModel)
                    .padding(.top, DesignTokens.Spacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ExperienceLevelFilterBar(
                selectedFilter: $localExperienceFilter
            )
            .padding(.horizontal, 20)

            DomainFilterBarSection(
                availableDomains: viewModel.availableDomains,
                selectedDomain: $localPickerDomain
            )
            .padding(.horizontal, 20)

            if viewModel.isShowingCachedJobs {
                CachedJobsBanner()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            List {
                ForEach(viewModel.filteredJobs) { job in
                    JobRow(
                        job: job,
                        isSaved: viewModel.isSaved(jobId: job.id),
                        onToggleSave: { viewModel.toggleSave(job) }
                    ) {
                        selectedJob = job
                    }
                }
                .listRowSeparator(.visible)
                .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Empty State

    private var emptyStateContent: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if !searchText.isEmpty {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.secondary)
                Text("No results for \"\(searchText)\"")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(.secondary)
                Text("Try adjusting your search or filters")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.tertiary)
            } else if localExperienceFilter != nil {
                Image(systemName: "briefcase.circle")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.secondary)
                Text("No \(localExperienceFilter!.displayName.lowercased()) jobs found")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(.secondary)
                Text("Try selecting a different filter")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.tertiary)
            } else if localPickerDomain != nil {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.secondary)
                Text("No jobs found for this criteria")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(.secondary)
                Text("Try selecting a different domain")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: "briefcase.circle")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.secondary)
                Text("No jobs available")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(.secondary)
                Text("No jobs match your profile yet. Check back later!")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Experience Level Filter Bar

private struct ExperienceLevelFilterBar: View {

    @Binding var selectedFilter: ExperienceLevel?

    private let filters: [(ExperienceLevel?, String, String)] = [
        (nil, "All Jobs", "square.grid.2x2"),
        (.student, "Internships", "graduationcap"),
        (.fresher, "Fresher", "leaf"),
        (.experienced, "Experienced", "star.fill")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(filters, id: \.0) { level, title, icon in
                    filterChip(level: level, title: title, icon: icon)
                }
            }
            .padding(.horizontal, 0)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private func filterChip(level: ExperienceLevel?, title: String, icon: String) -> some View {
        let isSelected = selectedFilter == level
        return Button {
            withAnimation(DesignTokens.Animations.springBouncy) {
                selectedFilter = level
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(DesignTokens.Typography.captionSemibold)
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? DesignTokens.Colors.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Domain Filter Bar Section

private struct DomainFilterBarSection: View {

    let availableDomains: [JobDomain]
    @Binding var selectedDomain: JobDomain?

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    allChip
                    ForEach(availableDomains) { domain in
                        domainChip(domain: domain)
                    }
                }
                .padding(.horizontal, 0)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private var allChip: some View {
        let isSelected = selectedDomain == nil
        return Button {
            withAnimation(DesignTokens.Animations.springBouncy) {
                selectedDomain = nil
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "square.grid.2x2")
                    .font(.caption2)
                Text("All")
                    .font(DesignTokens.Typography.captionSemibold)
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? DesignTokens.Colors.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func domainChip(domain: JobDomain) -> some View {
        let isSelected = selectedDomain == domain
        return Button {
            withAnimation(DesignTokens.Animations.springBouncy) {
                selectedDomain = domain
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: domain.iconName)
                    .font(.caption2)
                Text(domain.shortDisplayName)
                    .font(DesignTokens.Typography.captionSemibold)
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? DesignTokens.Colors.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
