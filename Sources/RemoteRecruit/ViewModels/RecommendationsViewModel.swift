// RecommendationsViewModel.swift
// RemoteRecruit

import Foundation

@MainActor
public final class RecommendationsViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) public var viewState: ViewState<[RecommendedJob]> = .idle

    // MARK: - Private

    private let engine: Recommending
    private let jobService: JobServiceProtocol

    // MARK: - Init

    public init(
        engine: Recommending = RecommendationEngine(),
        jobService: JobServiceProtocol = MockJobService()
    ) {
        self.engine = engine
        self.jobService = jobService
    }

    // MARK: - Public API

    /// Generates personalized recommendations based on the user profile.
    public func loadRecommendations() async {
        viewState = .loading

        let profile = AppState.shared.profile
        let userSkills = profile?.skills ?? AppState.shared.profileSkills
        let preferredDomain = profile.flatMap { JobDomain(rawValue: $0.domain) }
        let domains = preferredDomain.map { [$0] } ?? AppState.shared.preferredRoles.flatMap { $0.mappedJobDomains }
        let experienceLevel = profile.flatMap { ExperienceLevel(rawValue: $0.experienceLevel) }

        do {
            let allJobs = try await jobService.fetchJobs(for: nil)
            let recommendations = engine.recommend(
                jobs: allJobs,
                userSkills: userSkills,
                preferredDomains: domains,
                experienceLevel: experienceLevel
            )
            viewState = recommendations.isEmpty ? .empty : .success(data: recommendations)
        } catch {
            viewState = .error(message: error.localizedDescription)
        }
    }

    /// Refreshes recommendations.
    public func refresh() async {
        await loadRecommendations()
    }
}
