// DIContainer.swift
// RemoteRecruit

import Foundation

// MARK: - Dependency Container

/// Lightweight protocol-oriented dependency container.
/// Swap service implementations for testing or different environments.
public final class DIContainer {

    // MARK: - Shared Instance

    public static let shared = DIContainer()

    // MARK: - Services

    public let jobService: JobServiceProtocol
    public let searchService: JobSearchable
    public let aiService: AIServiceProtocol
    public let resumeParser: ResumeParsing
    public let applyService: ApplyServiceProtocol
    public let pluginManager: PluginManager
    public let syncService: ScraperSyncServiceProtocol
    public let matchingService: JobMatching
    public let savedJobsManager: SavedJobsManaging
    public let searchHistoryService: SearchHistoryManaging
    public let advancedFilterService: AdvancedFiltering
    public let recommendationEngine: Recommending
    public let cacheService: JobCaching
    public let applicationStatusManager: ApplicationStatusManaging

    // MARK: - Initializer

    /// Creates the container with the given service implementations.
    /// - Parameters:
    ///   - jobService: The job service to use (defaults to `RemoteJobService`).
    ///   - aiService: The AI resume analysis service to use (defaults to `MockAIService`).
    ///   - resumeParser: The resume parsing service to use (defaults to `MockResumeParser`).
    ///   - applyService: The apply service to use (defaults to `MockApplyService`).
    ///   - syncService: The scraper sync service to use (defaults to `MockScraperSyncService`).
    public init(
        jobService: JobServiceProtocol? = nil,
        searchService: JobSearchable? = nil,
        aiService: AIServiceProtocol? = nil,
        resumeParser: ResumeParsing? = nil,
        applyService: ApplyServiceProtocol? = nil,
        syncService: ScraperSyncServiceProtocol? = nil,
        matchingService: JobMatching? = nil,
        savedJobsManager: SavedJobsManaging? = nil,
        searchHistoryService: SearchHistoryManaging? = nil,
        advancedFilterService: AdvancedFiltering? = nil,
        recommendationEngine: Recommending? = nil,
        cacheService: JobCaching? = nil,
        applicationStatusManager: ApplicationStatusManaging? = nil
    ) {
        self.jobService = jobService ?? MockJobService()
        self.searchService = searchService ?? JobSearchService()
        self.aiService = aiService ?? MockAIService()
        self.resumeParser = resumeParser ?? MockResumeParser()
        let baseApplyService = applyService ?? MockApplyService()
        self.pluginManager = PluginManager(plugins: [
            AIResumeValidationPlugin(),
            ValidationPlugin(),
            LoggingPlugin(),
            AnalyticsPlugin(),
            AIApplicationEnhancementPlugin(),
        ])
        self.applyService = PluginAwareApplyService(
            inner: baseApplyService,
            pluginManager: pluginManager
        )
        self.syncService = syncService ?? MockScraperSyncService()
        self.matchingService = matchingService ?? JobMatchingService()
        self.savedJobsManager = savedJobsManager ?? SavedJobsManager()
        self.searchHistoryService = searchHistoryService ?? SearchHistoryService()
        self.advancedFilterService = advancedFilterService ?? AdvancedFilterService()
        self.recommendationEngine = recommendationEngine ?? RecommendationEngine()
        self.cacheService = cacheService ?? CacheService()
        self.applicationStatusManager = applicationStatusManager ?? ApplicationStatusManager()
    }

    // MARK: - Factories

    /// Creates a pre-configured `JobListViewModel` with the container's services.
    @MainActor
    public func makeJobListViewModel() -> JobListViewModel {
        JobListViewModel(
            service: jobService,
            filterService: JobFilterService(),
            searchService: searchService,
            cacheService: cacheService,
            savedJobsManager: savedJobsManager
        )
    }

    /// Creates a pre-configured `JobDetailViewModel` with the container's services.
    @MainActor
    public func makeJobDetailViewModel(job: Job) -> JobDetailViewModel {
        JobDetailViewModel(job: job, jobService: jobService, applyService: applyService)
 }

    /// Creates a `JobDetailViewModel` ready to fetch a job by ID.
    @MainActor
    public func makeJobDetailViewModel() -> JobDetailViewModel {
        JobDetailViewModel(jobService: jobService, applyService: applyService)
    }

    /// Creates a pre-configured `ResumeOptimizerViewModel` with the container's AI service.
    @MainActor
    public func makeResumeOptimizerViewModel() -> ResumeOptimizerViewModel {
        ResumeOptimizerViewModel(service: aiService)
    }

    /// Creates a pre-configured `ApplicationTrackerViewModel` with the container's services.
    @MainActor
    public func makeApplicationTrackerViewModel() -> ApplicationTrackerViewModel {
        ApplicationTrackerViewModel(
            syncService: syncService
        )
    }

    /// Creates a pre-configured `AuthenticationViewModel` with the default Firebase provider.
    @MainActor
    public func makeAuthenticationViewModel() -> AuthenticationViewModel {
        AuthenticationViewModel()
    }

    /// Creates a pre-configured `ProfileViewModel` with the container's resume parser.
    @MainActor
    public func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(resumeParser: resumeParser)
    }

    /// Creates a pre-configured `SearchViewModel` with the container's search history service.
    @MainActor
    public func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(historyService: searchHistoryService)
    }

    /// Creates a pre-configured `SavedJobsViewModel`.
    @MainActor
    public func makeSavedJobsViewModel() -> SavedJobsViewModel {
        SavedJobsViewModel(savedJobsManager: savedJobsManager, jobService: jobService)
    }

    /// Creates a pre-configured `RecommendationsViewModel`.
    @MainActor
    public func makeRecommendationsViewModel() -> RecommendationsViewModel {
        RecommendationsViewModel(engine: recommendationEngine, jobService: jobService)
    }

    /// Creates a pre-configured `ApplicationStatusViewModel`.
    @MainActor
    public func makeApplicationStatusViewModel(
        applicationId: String = "",
        initialStatus: ExtendedApplicationStatus = .applied
    ) -> ApplicationStatusViewModel {
        ApplicationStatusViewModel(
            applicationId: applicationId,
            initialStatus: initialStatus,
            statusManager: applicationStatusManager
        )
    }
}
