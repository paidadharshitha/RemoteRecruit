// PluginAwareApplyService.swift
// RemoteRecruit

import Foundation

// MARK: - Plugin-Aware Apply Service

/// Decorates an `ApplyServiceProtocol` with a `PluginManager` to inject
/// lifecycle hooks (logging, analytics, validation) into the application flow.
///
/// Usage:
/// ```swift
/// let baseService = FirebaseApplyService()
/// let pluginManager = PluginManager(plugins: [
///     ValidationPlugin(),
///     LoggingPlugin(),
///     AnalyticsPlugin(),
/// ])
/// let service = PluginAwareApplyService(
///     inner: baseService,
///     pluginManager: pluginManager
/// )
/// ```
public final class PluginAwareApplyService: ApplyServiceProtocol, Sendable {

    private let inner: ApplyServiceProtocol
    private let pluginManager: PluginManager

    public init(
        inner: ApplyServiceProtocol,
        pluginManager: PluginManager
    ) {
        self.inner = inner
        self.pluginManager = pluginManager
    }

    public func hasExistingApplication(jobId: String, userId: String) async throws -> Bool {
        try await inner.hasExistingApplication(jobId: jobId, userId: userId)
    }

    public func submitApplication(
        jobId: String,
        jobTitle: String,
        companyName: String,
        userId: String,
        resumeURL: String,
        jobListingURL: String?,
        isEasyApply: Bool,
        coverNote: String?
    ) async throws -> JobApplication {

        // ── Phase 1: willSubmit (validation + pre-hooks) ──
        var context = ApplicationPluginContext(
            jobId: jobId,
            jobTitle: jobTitle,
            companyName: companyName,
            userId: userId,
            resumeURL: resumeURL,
            jobListingURL: jobListingURL,
            isEasyApply: isEasyApply,
            coverNote: coverNote
        )

        await pluginManager.willSubmit(context: &context)

        // Check if any plugin reported validation errors
        if !context.validationErrors.isEmpty {
            let combinedMessage = context.validationErrors.joined(separator: " ")
            await pluginManager.didFail(context: context, error: ApplyError.custom(message: combinedMessage))
            throw ApplyError.custom(message: combinedMessage)
        }

        // ── Phase 2: Actual submission ──
        let application: JobApplication
        do {
            application = try await inner.submitApplication(
                jobId: jobId,
                jobTitle: jobTitle,
                companyName: companyName,
                userId: userId,
                resumeURL: resumeURL,
                jobListingURL: jobListingURL,
                isEasyApply: isEasyApply,
                coverNote: coverNote
            )
        } catch {
            await pluginManager.didFail(context: context, error: error)
            throw error
        }

        // ── Phase 3: didSubmit (success hooks) ──
        let successContext = ApplicationPluginContext(
            jobId: jobId,
            jobTitle: jobTitle,
            companyName: companyName,
            userId: userId,
            resumeURL: resumeURL,
            jobListingURL: jobListingURL,
            isEasyApply: isEasyApply,
            coverNote: coverNote,
            submittedApplication: application
        )
        await pluginManager.didSubmit(context: successContext)

        return application
    }
}
