// JobListView.swift
// RemoteRecruit

import SwiftUI

struct JobListView: View {

    @StateObject private var viewModel: JobListViewModel

    init(viewModel: JobListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
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
                        systemImage: viewModel.searchText.isEmpty ? "briefcase" : "magnifyingglass",
                        title: viewModel.searchText.isEmpty ? "No jobs available" : "No results",
                        message: viewModel.searchText.isEmpty
                            ? "There are no remote job listings right now. Check back soon!"
                            : "No jobs match \"\(viewModel.searchText)\". Try a different search."
                    )

                case .error(let message):
                    ErrorStateView(message: message) {
                        Task { await viewModel.refresh() }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.viewState.isLoading)
            .navigationTitle("RemoteRecruit")
            .searchable(text: $viewModel.searchText, prompt: "Search jobs by title or company…")
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

    // MARK: - Subviews

    private func jobList(jobs: [Job]) -> some View {
        List {
            ForEach(jobs) { job in
                NavigationLink(value: job) {
                    JobRowView(job: job)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: Job.self) { job in
            JobDetailView(job: job)
        }
    }
}

// MARK: - Job Row View

struct JobRowView: View {

    let job: Job

    var body: some View {
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
