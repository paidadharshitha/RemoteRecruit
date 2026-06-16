// JobListViewModel.swift
// RemoteRecruit

import Foundation

@MainActor
final class JobListViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var viewState: ViewState<[Job]> = .idle

    @Published var searchText: String = "" {
        didSet {
            applyFilter()
        }
    }

    // MARK: - Private

    private let service: JobServiceProtocol
    private var allJobs: [Job] = []

    // MARK: - Init

    init(service: JobServiceProtocol) {
        self.service = service
    }

    // MARK: - Public API

    /// Fetches all jobs from the service and updates view state.
    func loadJobs() async {
        guard !viewState.isLoading else { return }
        viewState = .loading

        do {
            let jobs = try await service.fetchJobs()
            allJobs = jobs
            applyFilter()
        } catch {
            viewState = .error(message: error.localizedDescription)
        }
    }

    /// Clears cached data and re-fetches. Useful for pull-to-refresh.
    func refresh() async {
        allJobs = []
        await loadJobs()
    }

    /// Applies the current search text filter over cached jobs.
    /// This is exposed publicly so tests can verify filter behavior directly.
    func applyFilter() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered: [Job]
        if trimmed.isEmpty {
            filtered = allJobs
        } else {
            filtered = allJobs.filter { job in
                job.title.lowercased().contains(trimmed)
                    || job.companyName.lowercased().contains(trimmed)
            }
        }

        if allJobs.isEmpty && !viewState.isLoading {
            viewState = .empty
        } else if filtered.isEmpty {
            viewState = .empty
        } else {
            viewState = .success(data: filtered)
        }
    }
}
