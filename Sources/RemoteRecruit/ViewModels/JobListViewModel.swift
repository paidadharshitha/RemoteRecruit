// JobListViewModel.swift
// RemoteRecruit

import Foundation
import Combine

@MainActor
public final class JobListViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) public var viewState: ViewState<[Job]> = .idle
    @Published private(set) public var filteredJobs: [Job] = []
    @Published private(set) public var activeDomainName: String = "All Jobs"
    @Published private(set) public var isShowingCachedJobs: Bool = false
    @Published public var savedJobIds: Set<String> = []

    /// The currently selected domain for the picker filter bar.
    /// Starts as `nil` ("All") and updates when the user taps a domain chip.
    @Published public var selectedDomainForPicker: JobDomain?

    /// The currently selected experience level filter.
    /// `nil` means "All Jobs" (no experience-level filtering).
    @Published public var selectedExperienceFilter: ExperienceLevel?

    /// The user's experience level derived from their Firestore profile.
    /// Used for server-side Firestore filtering.
    @Published public var effectiveExperienceLevel: ExperienceLevel = AppState.shared.selectedExperienceLevel

    /// Available domain chips scoped to the user's academic branch (if set), otherwise all domains.
    public var availableDomains: [JobDomain] {
        if let branch = AppState.shared.academicBranch {
            return branch.mappedJobDomains
        }
        return AppState.shared.selectedDiscipline.mappedRoles
    }

    // MARK: - Private

    private let service: JobServiceProtocol
    private let filterService: JobFiltering
    private let searchService: JobSearchable
    private let cacheService: JobCaching
    private let savedJobsManager: SavedJobsManaging
    private var allJobs: [Job] = []
    private var hasLoadedOnce = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    public init(
        service: JobServiceProtocol,
        filterService: JobFiltering,
        searchService: JobSearchable,
        cacheService: JobCaching = CacheService(),
        savedJobsManager: SavedJobsManaging = SavedJobsManager()
    ) {
        self.service = service
        self.filterService = filterService
        self.searchService = searchService
        self.cacheService = cacheService
        self.savedJobsManager = savedJobsManager
        self.savedJobIds = savedJobsManager.savedJobIds()

        // Sync experience level from profile when it loads/changes
        AppState.shared.$profile
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] profile in
                guard let self = self else { return }
                let newLevel: ExperienceLevel
                if let profile = profile,
                   let parsed = ExperienceLevel(rawValue: profile.experienceLevel) {
                    newLevel = parsed
                } else {
                    newLevel = AppState.shared.selectedExperienceLevel
                }
                guard newLevel != self.effectiveExperienceLevel else { return }
                self.effectiveExperienceLevel = newLevel
                if self.hasLoadedOnce { self.refreshFromFirestore() }
            }
            .store(in: &cancellables)

        // Sync domain from profile when it loads/changes
        AppState.shared.$profile
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] profile in
                guard let self = self, self.hasLoadedOnce else { return }
                // Only refresh if the domain actually changed
                let newDomain = profile?.domain ?? ""
                guard newDomain != (AppState.shared.userDomain?.rawValue ?? "") else { return }
                self.refreshFromFirestore()
            }
            .store(in: &cancellables)

        // Re-apply client-side filters when experience level changes in AppState
        AppState.shared.$selectedExperienceLevel
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                guard let self = self else { return }
                guard level != self.effectiveExperienceLevel else { return }
                self.effectiveExperienceLevel = level
                if self.hasLoadedOnce { self.refreshFromFirestore() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Fetches jobs from the injected service, then applies client-side filters.
    /// Works immediately without requiring Firebase auth or Firestore seeding.
    public func loadJobsWhenReady() async {
        guard !viewState.isLoading else { return }
        viewState = .loading
        await fetchAndApplyJobs()
    }

    /// Fetches all jobs from the injected service, then client-side filters.
    public func loadJobs() async {
        guard !viewState.isLoading else { return }
        viewState = .loading
        await fetchAndApplyJobs()
    }

    /// Returns whether the user has already applied to the given job.
    public func hasApplied(to jobId: String) -> Bool {
        AppState.shared.hasApplied(to: jobId)
    }

    /// Core fetch logic — uses `fetchFilteredJobs` with domain + experienceLevel.
    private func fetchAndApplyJobs() async {
        isShowingCachedJobs = false
        do {
            let domainFilter = selectedDomainForPicker?.rawValue
            let levelFilter = effectiveExperienceLevel.rawValue
            let jobs = try await service.fetchFilteredJobs(domain: domainFilter, experienceLevel: levelFilter)
            allJobs = jobs
            hasLoadedOnce = true
            // Cache successful results
            try? await cacheService.cacheJobs(jobs)
            applyFilter()
        } catch {
            // Try loading from cache
            if let envelope = try? await cacheService.loadCachedJobs(), !envelope.isExpired {
                allJobs = envelope.jobs
                hasLoadedOnce = true
                isShowingCachedJobs = true
                applyFilter()
            } else if hasLoadedOnce && !allJobs.isEmpty {
                applyFilter() // Keep showing previously loaded data
            } else {
                viewState = .error(message: error.localizedDescription)
            }
        }
    }

    /// Clears cached data and re-fetches. Useful for pull-to-refresh.
    public func refresh() async {
        allJobs = []
        await loadJobs()
    }

    /// Called when the domain picker selection changes.
    /// Re-fetches from Firestore with the new domain + existing experience level.
    public func domainPickerDidChange(_ domain: JobDomain?) {
        selectedDomainForPicker = domain
        activeDomainName = domain?.rawValue ?? "All Jobs"
        refreshFromFirestore()
    }

    /// Triggers a non-blocking Firestore re-fetch using current filters.
    /// Skips the refresh if the service would be called with the same parameters
    /// as the last successful fetch (prevents redundant loading spinners on Combine re-emits).
    private func refreshFromFirestore() {
        Task {
            guard !viewState.isLoading else { return }
            viewState = .loading
            await fetchAndApplyJobs()
        }
    }

    /// Fetches jobs from the injected service, then client-side filters by skills.
    /// Falls back to domain-filtered results if no skill matches are found.
    public func loadJobsMatchingSkills(_ skills: [String]) async {
        guard !viewState.isLoading else { return }
        viewState = .loading

        activeDomainName = "Recommended for you"

        do {
            let allFetched = try await service.fetchJobs(for: nil)

            guard !skills.isEmpty else {
                allJobs = allFetched
                applyFilter()
                return
            }

            let lowercasedSkills = skills.map { $0.lowercased() }
            let matched = allFetched.filter { job in
                job.tags.contains { tag in
                    lowercasedSkills.contains { tag.lowercased().contains($0) || $0.contains(tag.lowercased()) }
                }
            }

            allJobs = matched.isEmpty ? allFetched : matched
            applyFilter()
        } catch {
            viewState = .error(message: error.localizedDescription)
        }
    }

    /// Applies search text + domain filter + experience level filter over all cached jobs.
    /// All three filters (search, domain, experience) work together.
    public func applyFilter() {
        let searchQuery = AppState.shared.searchText.trimmingCharacters(in: .whitespaces)

        var filtered = allJobs

        // Experience level filter (client-side)
        if let level = selectedExperienceFilter {
            filtered = filtered.filter { $0.experienceLevel == level }
        }

        // Client-side search text filter (delegated to JobSearchService)
        if !searchQuery.isEmpty {
            filtered = searchService.search(jobs: filtered, query: searchQuery)
        }

        self.filteredJobs = filtered

        if allJobs.isEmpty && !viewState.isLoading {
            viewState = .empty
        } else if filtered.isEmpty && hasLoadedOnce {
            viewState = .empty
        } else if !filtered.isEmpty {
            viewState = .success(data: filtered)
        }
    }

    public func toggleSave(_ job: Job) {
        if savedJobsManager.isSaved(jobId: job.id) {
            savedJobsManager.removeJob(jobId: job.id)
            savedJobIds.remove(job.id)
        } else {
            savedJobsManager.saveJob(job)
            savedJobIds.insert(job.id)
        }
    }

    public func isSaved(jobId: String) -> Bool {
        savedJobIds.contains(jobId)
    }
}
