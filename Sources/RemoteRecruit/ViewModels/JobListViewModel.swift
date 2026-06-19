// JobListViewModel.swift
// RemoteRecruit

import Foundation

@MainActor
public final class JobListViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) public var viewState: ViewState<[Job]> = .idle
    @Published private(set) public var filteredJobs: [Job] = []
    @Published private(set) public var activeDomainName: String = "All Jobs"

    /// The currently selected discipline — drives the discipline Picker in JobListView.
    @Published public var selectedDiscipline: AcademicDiscipline = AppState.shared.selectedDiscipline

    /// The currently selected experience level — drives the level Picker in JobListView.
    @Published public var selectedLevel: ExperienceLevel = AppState.shared.selectedExperienceLevel

    /// Current preferred roles from AppState (reactive).
    @Published private(set) public var preferredRoles: [TechnicalRole] = AppState.shared.preferredRoles

    /// Current academic branch from AppState (reactive).
    @Published private(set) public var academicBranch: AcademicDomain? = AppState.shared.academicBranch

    // MARK: - Private

    private let service: JobServiceProtocol
    private let filterService: JobFiltering
    private var allJobs: [Job] = []

    // MARK: - Init

    public init(service: JobServiceProtocol, filterService: JobFiltering) {
        self.service = service
        self.filterService = filterService
    }

    // MARK: - Public API

    /// Fetches all jobs from the injected service, then client-side filters by discipline and level.
    public func loadJobs() async {
        guard !viewState.isLoading else { return }
        viewState = .loading

        do {
            let jobs = try await service.fetchJobs(for: nil)
            allJobs = jobs
            applyFilter()
        } catch {
            viewState = .error(message: error.localizedDescription)
        }
    }

    /// Clears cached data and re-fetches. Useful for pull-to-refresh.
    public func refresh() async {
        allJobs = []
        await loadJobs()
    }

    /// Fetches jobs from the injected service, then client-side filters by skills.
    /// Falls back to domain-filtered results if no skill matches are found.
    /// - Parameter skills: Array of skills from resume parsing.
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

    /// Syncs preferences from AppState (called when AppState changes).
    private func syncPreferencesFromAppState() {
        preferredRoles = AppState.shared.preferredRoles
        academicBranch = AppState.shared.academicBranch
    }

    /// Applies role-based, discipline, experience level, and search text filters over cached jobs.
    /// When the user has preferred roles set, those take priority over discipline-only filtering.
    public func applyFilter() {
        let level = selectedLevel
        let searchQuery = AppState.shared.searchText
        let roles = AppState.shared.preferredRoles
        let branch = AppState.shared.academicBranch
        let discipline = selectedDiscipline

        // Sync local copies
        preferredRoles = roles
        academicBranch = branch

        // Choose filter strategy: role-based if preferences exist, otherwise discipline-based
        var filtered: [Job]

        if !roles.isEmpty || branch != nil {
            // Role-based filtering: preferredRoles → JobDomain mapping + experienceLevel
            activeDomainName = roleBasedFilterName(roles: roles, branch: branch, level: level)
            filtered = filterService.filterJobsByRoles(
                jobs: allJobs,
                preferredRoles: roles,
                academicBranch: branch,
                level: level
            )
        } else {
            // Fallback: original discipline-based filtering
            activeDomainName = discipline.shortName + " · " + level.rawValue
            filtered = filterService.filterJobs(jobs: allJobs, discipline: discipline, level: level)
        }

        // Secondary filter: search text
        if !searchQuery.isEmpty {
            filtered = filtered.filter { job in
                job.title.localizedCaseInsensitiveContains(searchQuery)
                    || job.companyName.localizedCaseInsensitiveContains(searchQuery)
                    || job.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchQuery) })
            }
        }

        self.filteredJobs = filtered

        if allJobs.isEmpty && !viewState.isLoading {
            viewState = .empty
        } else if filtered.isEmpty {
            viewState = .empty
        } else {
            viewState = .success(data: filtered)
        }
    }

    /// Builds a display name for the filter banner when role-based filtering is active.
    private func roleBasedFilterName(roles: [TechnicalRole], branch: AcademicDomain?, level: ExperienceLevel) -> String {
        if !roles.isEmpty {
            let roleNames = roles.map { $0.rawValue }
            return roleNames.joined(separator: ", ") + " · " + level.rawValue
        } else if let branch = branch {
            return branch.rawValue + " · " + level.rawValue
        }
        return level.rawValue
    }
}
