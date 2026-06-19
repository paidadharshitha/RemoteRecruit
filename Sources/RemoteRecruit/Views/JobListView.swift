// JobListView.swift
// RemoteRecruit

import SwiftUI

public struct JobListView: View {

    @StateObject private var viewModel: JobListViewModel
    @StateObject private var appState = AppState.shared

    public init(viewModel: JobListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.viewState {
                case .idle:
                    LoadingStateView(message: "Preparing to load…")
                        .onAppear { Task { await viewModel.loadJobs() } }

                case .loading:
                    LoadingStateView(message: "Fetching remote jobs…")

                case .success(let jobs):
                    jobList(jobs: jobs)

                case .empty:
                    EmptyStateView(
                        systemImage: appState.searchText.isEmpty
                            ? (viewModel.preferredRoles.isEmpty ? "briefcase" : "slider.horizontal.3")
                            : "magnifyingglass",
                        title: appState.searchText.isEmpty
                            ? (viewModel.preferredRoles.isEmpty ? "No jobs found for this category" : "No matching jobs")
                            : "No results",
                        message: appState.searchText.isEmpty
                            ? (viewModel.preferredRoles.isEmpty
                                ? "No jobs match \(viewModel.selectedDiscipline.shortName) · \(viewModel.selectedLevel.rawValue). Try a different filter."
                                : "No jobs match your selected preferences. Try updating your profile roles.")
                            : "No jobs match \"\(appState.searchText)\". Try a different search."
                    )

                case .error(let message):
                    ErrorStateView(message: message) {
                        Task { await viewModel.refresh() }
                    }
                }
            }
            .onChange(of: viewModel.selectedDiscipline) {
                appState.selectedDiscipline = viewModel.selectedDiscipline
                viewModel.applyFilter()
            }
            .onChange(of: viewModel.selectedLevel) {
                appState.selectedExperienceLevel = viewModel.selectedLevel
                viewModel.applyFilter()
            }
            .onChange(of: appState.searchText) {
                viewModel.applyFilter()
 }
            .onChange(of: appState.preferredRoles) {
                viewModel.applyFilter()
 }
            .onChange(of: appState.academicBranch) {
                viewModel.applyFilter()
 }
            .animation(DesignTokens.Animations.fade, value: viewModel.viewState.isLoading)
            .animation(DesignTokens.Animations.spring, value: viewModel.selectedDiscipline)
            .animation(DesignTokens.Animations.spring, value: viewModel.selectedLevel)
            .navigationTitle("RemoteRecruit")
            .searchable(text: $appState.searchText, prompt: "Search jobs by title, company, or tags…")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Menu {
                        disciplinePickerMenu
                        Divider()
                        levelPickerMenu
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .task {
                if case .idle = viewModel.viewState {
                    await viewModel.loadJobs()
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Picker Menus

    private var disciplinePickerMenu: some View {
        Section {
            Picker("Discipline", selection: $viewModel.selectedDiscipline) {
                ForEach(AcademicDiscipline.allCases) { discipline in
                    Label(discipline.rawValue, systemImage: discipline.iconName)
                        .tag(discipline)
                }
            }
        }
    }

    private var levelPickerMenu: some View {
        Section {
            Picker("Experience Level", selection: $viewModel.selectedLevel) {
                ForEach(ExperienceLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
        }
    }

    // MARK: - Subviews

    private func jobList(jobs: [Job]) -> some View {
        List {
            // Filter Banner
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.filter")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.activeDomainName)")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.tint.opacity(0.1), in: Capsule())
                    Text("\(jobs.count) jobs")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
            }

            // Preferences Summary Banner
            if !viewModel.preferredRoles.isEmpty {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "star.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                        Text("Showing roles:")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(viewModel.preferredRoles.sorted { $0.rawValue < $1.rawValue }) { role in
                                    Text(role.rawValue)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }

            Section {
            ForEach(jobs) { job in
                    NavigationLink(value: job) {
                        JobRowView(job: job)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xs, leading: DesignTokens.Spacing.lg, bottom: DesignTokens.Spacing.xs, trailing: DesignTokens.Spacing.lg))
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                            .fill(DesignTokens.Colors.surface)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                    )
                }
            }
        }
        .id(viewModel.selectedDiscipline.rawValue
             + viewModel.selectedLevel.rawValue
             + appState.searchText)
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
        .navigationDestination(for: Job.self) { job in
            JobDetailView(job: job)
        }
    }
}

// MARK: - Job Row View

public struct JobRowView: View {

    public let job: Job

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(job.title)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 6) {
                Image(systemName: "building.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(job.companyName)
                    .font(.subheadline.weight(.medium))
            }

            HStack(spacing: 6) {
                Image(systemName: "mappin")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(job.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Image(systemName: "banknote")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text(job.salaryRange)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }

            if !job.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(job.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.fill.tertiary, in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
