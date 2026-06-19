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
    public let aiService: AIServiceProtocol
    public let resumeParser: ResumeParsing
    public let applyService: ApplyServiceProtocol
    public let pluginManager: PluginManager
    public let syncService: ScraperSyncServiceProtocol

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
        aiService: AIServiceProtocol? = nil,
        resumeParser: ResumeParsing? = nil,
        applyService: ApplyServiceProtocol? = nil,
        syncService: ScraperSyncServiceProtocol? = nil
    ) {
        self.jobService = jobService ?? RemoteJobService()
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
    }

    // MARK: - Factories

    /// Creates a pre-configured `JobListViewModel` with the container's service.
    @MainActor
    public func makeJobListViewModel() -> JobListViewModel {
        JobListViewModel(service: jobService, filterService: JobFilterService())
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
}
