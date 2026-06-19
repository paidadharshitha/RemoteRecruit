// ApplicationPlugin.swift
// RemoteRecruit

import Foundation

// MARK: - Plugin Context

/// Carries contextual data through the plugin pipeline.
public struct ApplicationPluginContext: Sendable {

    /// The job being applied to.
    public let jobId: String
    public let jobTitle: String
    public let companyName: String
    public let userId: String

    /// The resume URL used for the application.
    public let resumeURL: String
    public let jobListingURL: String?
    public let isEasyApply: Bool
    public let coverNote: String?

    /// The created application (available only after submission succeeds).
    public var submittedApplication: JobApplication?

    /// Accumulated validation errors from plugins.
    public var validationErrors: [String] = []

    public init(
        jobId: String,
        jobTitle: String,
        companyName: String,
        userId: String,
        resumeURL: String,
        jobListingURL: String?,
        isEasyApply: Bool,
        coverNote: String?,
        submittedApplication: JobApplication? = nil,
        validationErrors: [String] = []
    ) {
        self.jobId = jobId
        self.jobTitle = jobTitle
        self.companyName = companyName
        self.userId = userId
        self.resumeURL = resumeURL
        self.jobListingURL = jobListingURL
        self.isEasyApply = isEasyApply
        self.coverNote = coverNote
        self.submittedApplication = submittedApplication
        self.validationErrors = validationErrors
    }
}

// MARK: - Plugin Protocol

/// A pluggable hook that participates in the application lifecycle.
///
/// Plugins are invoked in the order they are registered. Validation plugins
/// run before submission; logging/analytics run after.
public protocol ApplicationPlugin: Sendable, Identifiable {
    /// Unique identifier for this plugin.
    var id: String { get }

    /// Display name for debugging.
    var name: String { get }

    /// Called before the application is submitted. Plugins can validate
    /// data by appending to `context.validationErrors`.
    /// - Parameter context: Mutable context with the pending application data.
    func willSubmit(context: inout ApplicationPluginContext) async

    /// Called after the application is successfully submitted.
    /// - Parameter context: Context now includes the created `JobApplication`.
    func didSubmit(context: ApplicationPluginContext) async

    /// Called if the submission fails with an error.
    /// - Parameter context: The context at the time of failure.
    /// - Parameter error: The error that caused the failure.
    func didFail(context: ApplicationPluginContext, error: Error) async
}

// MARK: - Plugin Manager

/// Thread-safe manager that holds an ordered list of plugins and executes
/// them at each lifecycle stage.
public final class PluginManager: Sendable {

    private let plugins: Lock<[any ApplicationPlugin]>

    public init(plugins: [any ApplicationPlugin] = []) {
        self.plugins = Lock(plugins)
    }

    /// Registers a plugin. If a plugin with the same `id` exists, it is replaced.
    public func register(_ plugin: any ApplicationPlugin) async {
        await plugins.withValue { list in
            if let index = list.firstIndex(where: { $0.id == plugin.id }) {
                list[index] = plugin
            } else {
                list.append(plugin)
            }
        }
    }

    /// Unregisters a plugin by its identifier.
    public func unregister(id: String) async {
        await plugins.withValue { list in
            list.removeAll { $0.id == id }
        }
    }

    /// Returns all registered plugins.
    public func allPlugins() async -> [any ApplicationPlugin] {
        await plugins.withValue { $0 }
    }

    // MARK: - Lifecycle

    /// Runs all plugins' `willSubmit` phase. Aggregates validation errors.
    public func willSubmit(context: inout ApplicationPluginContext) async {
        let snapshot = await plugins.withValue { $0 }
        for plugin in snapshot {
            await plugin.willSubmit(context: &context)
        }
    }

    /// Runs all plugins' `didSubmit` phase.
    public func didSubmit(context: ApplicationPluginContext) async {
        let snapshot = await plugins.withValue { $0 }
        for plugin in snapshot {
            await plugin.didSubmit(context: context)
        }
    }

    /// Runs all plugins' `didFail` phase.
    public func didFail(context: ApplicationPluginContext, error: Error) async {
        let snapshot = await plugins.withValue { $0 }
        for plugin in snapshot {
            await plugin.didFail(context: context, error: error)
        }
    }
}

// MARK: - Thread-Safe Lock

/// Minimal actor-based lock for protecting mutable state across concurrency domains.
final class Lock<Value>: Sendable {
    private let storage: LockStorageActor<Value>

    init(_ value: Value) {
        self.storage = LockStorageActor(value)
    }

    func withValue<R>(_ body: (inout Value) -> R) async -> R {
        await storage.withValue(body)
    }
}

/// Internal actor that holds the mutable state for `Lock`.
private actor LockStorageActor<Value> {
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withValue<R>(_ body: (inout Value) -> R) -> R {
        return body(&value)
    }
}
