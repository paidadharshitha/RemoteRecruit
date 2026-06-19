// BuiltInPlugins.swift
// RemoteRecruit

import Foundation

// MARK: - Logging Plugin

/// Logs every stage of the application lifecycle for debugging and auditing.
public struct LoggingPlugin: ApplicationPlugin, Sendable {

    public let id = "com.remoterecruit.plugin.logging"
    public let name = "Logging Plugin"

    private let logger: @Sendable (String) -> Void

    /// Creates a logging plugin with a custom log handler.
    /// - Parameter logger: Closure that receives log messages. Defaults to `print`.
    public init(logger: @escaping @Sendable (String) -> Void = { print("[LoggingPlugin] \($0)") }) {
        self.logger = logger
    }

    public func willSubmit(context: inout ApplicationPluginContext) async {
        logger("Preparing submission for '\(context.jobTitle)' at \(context.companyName)")
        logger("  Easy Apply: \(context.isEasyApply), Cover Note: \(context.coverNote == nil ? "none" : "provided")")
    }

    public func didSubmit(context: ApplicationPluginContext) async {
        guard let application = context.submittedApplication else { return }
        logger("Application submitted successfully — id: \(application.id)")
    }

    public func didFail(context: ApplicationPluginContext, error: Error) async {
        logger("Application submission failed — \(error.localizedDescription)")
    }
}

// MARK: - Analytics Plugin

/// Tracks application events for product analytics (e.g. Firebase Analytics, Mixpanel).
/// Replace the body of the tracking methods with real analytics SDK calls.
public struct AnalyticsPlugin: ApplicationPlugin, Sendable {

    public let id = "com.remoterecruit.plugin.analytics"
    public let name = "Analytics Plugin"

    private let trackEvent: @Sendable (String, [String: String]) -> Void

    /// Creates an analytics plugin with a custom event tracker.
    /// - Parameter trackEvent: Closure that receives event name and properties.
    public init(trackEvent: @escaping @Sendable (String, [String: String]) -> Void = { name, props in
        print("[AnalyticsPlugin] Event: \(name) — \(props)")
    }) {
        self.trackEvent = trackEvent
    }

    public func willSubmit(context: inout ApplicationPluginContext) async {
        trackEvent("application_started", [
            "job_id": context.jobId,
            "company": context.companyName,
            "is_easy_apply": String(context.isEasyApply),
        ])
    }

    public func didSubmit(context: ApplicationPluginContext) async {
        guard let application = context.submittedApplication else { return }
        trackEvent("application_submitted", [
            "application_id": application.id,
            "job_id": context.jobId,
            "company": context.companyName,
        ])
    }

    public func didFail(context: ApplicationPluginContext, error: Error) async {
        trackEvent("application_failed", [
            "job_id": context.jobId,
            "error": error.localizedDescription,
        ])
    }
}

// MARK: - Validation Plugin

/// Validates application data before submission. Any errors appended to
/// `context.validationErrors` will prevent the application from being submitted.
public struct ValidationPlugin: ApplicationPlugin, Sendable {

    public let id = "com.remoterecruit.plugin.validation"
    public let name = "Validation Plugin"

    /// Optional list of custom validation rules.
    private let rules: [@Sendable (ApplicationPluginContext) -> String?]

    /// Creates a validation plugin with default checks.
    /// - Parameter rules: Additional custom rules. Each returns an error message, or `nil` if valid.
    public init(rules: [@Sendable (ApplicationPluginContext) -> String?] = []) {
        self.rules = rules
    }

    public func willSubmit(context: inout ApplicationPluginContext) async {
        // Default built-in validations
        if context.userId.isEmpty {
            context.validationErrors.append("User ID must not be empty.")
        }
        if context.resumeURL.isEmpty {
            context.validationErrors.append("Resume URL must not be empty.")
        }
        if context.jobId.isEmpty {
            context.validationErrors.append("Job ID must not be empty.")
        }

        // Custom rule validations
        for rule in rules {
            if let message = rule(context) {
                context.validationErrors.append(message)
            }
        }
    }

    public func didSubmit(context: ApplicationPluginContext) async {
        // Nothing to do on success for validation
    }

    public func didFail(context: ApplicationPluginContext, error: Error) async {
        // Nothing to do on failure for validation
    }
}

// MARK: - AI Resume Validation Plugin

/// Pre-submission plugin that validates the resume file exists locally
/// before the application is sent. Uses `ResumePathResolver` to check both
/// local `file://` and remote URLs.
///
/// This plugin runs automatically via the `PluginAwareApplyService` pipeline.
public struct AIResumeValidationPlugin: ApplicationPlugin, Sendable {

    public let id = "com.remoterecruit.plugin.ai-resume-validation"
    public let name = "AI Resume Validation Plugin"

    public func willSubmit(context: inout ApplicationPluginContext) async {
        let resumeURL = context.resumeURL
        guard !resumeURL.isEmpty else {
            context.validationErrors.append("No resume provided. Please upload a resume before applying.")
            return
        }

        let resolved = ResumePathResolver.resolve(resumeURL)
        switch resolved {
        case .found(let localPath):
            print("[AIResumeValidation] ✅ Resume file verified: \(localPath)")

        case .notFound(let resolvedPath, _):
            print("[AIResumeValidation] ❌ Resume not found at: \(resolvedPath)")
            context.validationErrors.append(
                "Resume file not found at the expected path. Please re-upload your resume."
            )

        case .remote:
            // Remote URLs cannot be verified locally — trust the URL
            print("[AIResumeValidation] Remote resume URL, skipping local check: \(resumeURL)")

        case .invalidFormat(let raw):
            print("[AIResumeValidation] ❌ Invalid resume URL format: \"\(raw)\"")
            context.validationErrors.append(
                "Resume URL is invalid. Please re-upload your resume."
            )
        }
    }

    public func didSubmit(context: ApplicationPluginContext) async {
        guard let application = context.submittedApplication else { return }
        print("[AIResumeValidation] Resume validated for application \(application.id)")
    }

    public func didFail(context: ApplicationPluginContext, error: Error) async {
        print("[AIResumeValidation] Application failed before resume validation completed: \(error.localizedDescription)")
    }
}

// MARK: - AI Application Enhancement Plugin

/// Post-submission plugin that extracts AI-relevant metadata from a successful
/// application. Logs job title, company, and resume URL for future AI-driven
/// features such as:
/// - Automated skills-match scoring
/// - Resume tailoring suggestions
/// - Application follow-up reminders
/// - Job recommendation refinement
///
/// Currently logs to console; replace the body of `logMetadata` with real
/// analytics or Firestore writes when ready.
public struct AIApplicationEnhancementPlugin: ApplicationPlugin, Sendable {

    public let id = "com.remoterecruit.plugin.ai-application-enhancement"
    public let name = "AI Application Enhancement Plugin"

    /// Callback for processing AI metadata. Defaults to `print`.
    private let logMetadata: @Sendable (String, [String: String]) -> Void

    public init(logMetadata: @escaping @Sendable (String, [String: String]) -> Void = { name, props in
        print("[AIAppEnhancement] Event: \(name) — \(props)")
    }) {
        self.logMetadata = logMetadata
    }

    public func willSubmit(context: inout ApplicationPluginContext) async {
        // Log pre-submission metadata for AI tracking
        logMetadata("application_pre_submit", [
            "job_id": context.jobId,
            "job_title": context.jobTitle,
            "company_name": context.companyName,
            "is_easy_apply": String(context.isEasyApply),
            "has_resume": String(!context.resumeURL.isEmpty),
            "has_cover_note": String(context.coverNote != nil),
        ])
    }

    public func didSubmit(context: ApplicationPluginContext) async {
        guard let application = context.submittedApplication else { return }

        logMetadata("application_submitted_ai", [
            "application_id": application.id,
            "job_id": context.jobId,
            "job_title": context.jobTitle,
            "company_name": context.companyName,
            "resume_url": context.resumeURL,
            "submitted_at": application.lastSyncedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "unknown",
            "status": application.status.rawValue,
        ])

        // Future: trigger AI skills-match analysis against this job
        // Future: generate tailored resume suggestions based on job requirements
        // Future: schedule follow-up reminder based on job type
    }

    public func didFail(context: ApplicationPluginContext, error: Error) async {
        logMetadata("application_failed_ai", [
            "job_id": context.jobId,
            "company_name": context.companyName,
            "error": error.localizedDescription,
        ])
    }
}
