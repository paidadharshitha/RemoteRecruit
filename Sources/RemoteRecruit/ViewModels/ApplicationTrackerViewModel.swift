// ApplicationTrackerViewModel.swift
// RemoteRecruit

import Foundation
import FirebaseFirestore

// MARK: - Application Tracker ViewModel

@MainActor
public final class ApplicationTrackerViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) public var viewState: ViewState<[JobApplication]> = .idle
    @Published private(set) public var isSyncing = false
    @Published private(set) public var syncingApplicationId: String?
    @Published public var activeStatusFilter: ApplicationStatus?

    // MARK: - Private

    private let applicationService: ApplicationService
    private let syncService: ScraperSyncServiceProtocol
    private var allApplications: [JobApplication] = []

    // MARK: - Init

    public init(
        applicationService: ApplicationService,
        syncService: ScraperSyncServiceProtocol
    ) {
        self.applicationService = applicationService
        self.syncService = syncService
    }

    /// Convenience initializer using the shared `ApplicationService`.
    public convenience init(syncService: ScraperSyncServiceProtocol) {
        self.init(applicationService: .shared, syncService: syncService)
    }

    // MARK: - Public API

    /// Loads all applications for the given user.
    public func loadApplications(userId: String) async {
        guard !viewState.isLoading else { return }
        viewState = .loading

        do {
            let applications = try await applicationService.fetchApplications(userId: userId)
            allApplications = applications.sorted { $0.status.sortPriority < $1.status.sortPriority }
            applyFilter()
        } catch {
            viewState = .error(message: error.localizedDescription)
        }
    }

    /// Refreshes the application list (pull-to-refresh).
    public func refresh(userId: String) async {
        allApplications = []
        await loadApplications(userId: userId)
    }

    /// Sets the active status filter and re-filters the cached list.
    public func setFilter(_ status: ApplicationStatus?) {
        activeStatusFilter = status
        applyFilter()
    }

    /// Batch-syncs all applications for a user.
    public func batchSync(userId: String) async {
        guard !isSyncing else { return }
        isSyncing = true

        do {
            let updated = try await syncService.batchSync(userId: userId)
            allApplications = updated.sorted { $0.status.sortPriority < $1.status.sortPriority }
            applyFilter()
        } catch {
            // Silently fail sync but preserve existing data
            print("[ApplicationTrackerViewModel] Batch sync failed: \\(error.localizedDescription)")
        }

        isSyncing = false
    }

    /// Re-syncs a single application's status.
    public func resyncApplication(_ application: JobApplication) async {
        guard !isSyncing else { return }
        syncingApplicationId = application.id
        isSyncing = true

        do {
            let newStatus = try await syncService.syncApplicationStatus(
                applicationId: application.id,
                jobId: application.jobId
            )

            // Update the local copy
            if let index = allApplications.firstIndex(where: { $0.id == application.id }) {
                allApplications[index] = JobApplication(
                    id: application.id,
                    jobId: application.jobId,
                    jobTitle: application.jobTitle,
                    companyName: application.companyName,
                    userId: application.userId,
                    resumeURL: application.resumeURL,
                    status: newStatus,
                    timestamp: application.timestamp,
                    lastSyncedAt: Date(),
                    syncStatus: .synced,
                    jobListingURL: application.jobListingURL
                )
            }

            applyFilter()
        } catch {
            print("[ApplicationTrackerViewModel] Single sync failed: \\(error.localizedDescription)")
        }

        syncingApplicationId = nil
        isSyncing = false
    }

    /// Returns the URL for a manual check of a specific job listing.
    public func manualCheckURL(for jobId: String) -> String? {
        syncService.manualCheckURL(for: jobId)
    }

    // MARK: - Status Counts

    /// Count of applications in each status category.
    public func count(for status: ApplicationStatus) -> Int {
        allApplications.filter { $0.status == status }.count
    }

    /// Total number of applications.
    public var totalCount: Int {
        allApplications.count
    }

    /// Count of applications that need attention (stale or failed sync).
    public var needsAttentionCount: Int {
        allApplications.filter { $0.syncStatus.requiresAction }.count
    }

    // MARK: - Private

    private func applyFilter() {
        let filtered: [JobApplication]
        if let status = activeStatusFilter {
            filtered = allApplications.filter { $0.status == status }
        } else {
            filtered = allApplications
        }

        if filtered.isEmpty && !viewState.isLoading {
            viewState = allApplications.isEmpty ? .empty : .success(data: [])
        } else {
            viewState = .success(data: filtered)
        }
    }
}
