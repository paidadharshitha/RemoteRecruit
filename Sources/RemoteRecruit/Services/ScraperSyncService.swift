// ScraperSyncService.swift
// RemoteRecruit

import Foundation
import FirebaseFirestore

// MARK: - Sync Error

public enum ScraperSyncError: LocalizedError, Equatable, Sendable {
    case networkUnavailable
    case scraperTimeout
    case noStatusChange
    case custom(message: String)

    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network is unavailable. Cannot sync status."
        case .scraperTimeout:
            return "The scraper timed out. Please try again or check manually."
        case .noStatusChange:
            return "No status change detected. The application status is still the same."
        case .custom(let message):
            return message
        }
    }
}

// MARK: - Protocol

public protocol ScraperSyncServiceProtocol: AnyObject, Sendable {
    /// Syncs the status of a single application by polling the scraper.
    /// Returns the updated application status, or throws on failure.
    /// - Note: Implementors should be `@MainActor`-isolated or use internal actor isolation.
    func syncApplicationStatus(applicationId: String, jobId: String) async throws -> ApplicationStatus

    /// Batch-syncs all applications for a user. Returns updated applications.
    func batchSync(userId: String) async throws -> [JobApplication]

    /// Returns the external job listing URL for manual check, if available.
    func manualCheckURL(for jobId: String) -> String?
}

// MARK: - Firebase Implementation

public final class FirebaseScraperSyncService: ScraperSyncServiceProtocol, @unchecked Sendable {

    private let db = Firestore.firestore()

    public init() {}

    public func syncApplicationStatus(applicationId: String, jobId: String) async throws -> ApplicationStatus {
        // Simulate polling the scraper — in production, this would hit a Cloud Function
        // that scrapes the job board and returns the updated status.

        // First, read the current application
        let doc = try await db.collection("applications").document(applicationId).getDocument()

        guard doc.exists else {
            throw ScraperSyncError.custom(message: "Application not found.")
        }

        // In production: call a Cloud Function to scrape the job board
        // For now, update the lastSyncedAt timestamp to indicate a successful sync attempt
        let currentStatus = doc.data()?["status"] as? String ?? ApplicationStatus.applied.rawValue

        try await db.collection("applications").document(applicationId).updateData([
            "lastSyncedAt": FieldValue.serverTimestamp(),
            "syncStatus": SyncStatus.synced.rawValue
        ])

        return ApplicationStatus(rawValue: currentStatus) ?? .applied
    }

    public func batchSync(userId: String) async throws -> [JobApplication] {
        // Fetch all applications for this user
        let snapshot = try await db.collection("applications")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .getDocuments()

        var updatedApplications: [JobApplication] = []

        for doc in snapshot.documents {
            let applicationId = doc.documentID

            // Update sync timestamp for each application
            try await db.collection("applications").document(applicationId).updateData([
                "lastSyncedAt": FieldValue.serverTimestamp(),
                "syncStatus": SyncStatus.synced.rawValue
            ])

            if let data = try? doc.data(as: JobApplication.self) {
                updatedApplications.append(data)
            }
        }

        return updatedApplications
    }

    public func manualCheckURL(for jobId: String) -> String? {
        // In production, this would look up the original job listing URL from the jobs collection.
        // For now, return nil to indicate no direct URL is available.
        return nil
    }
}

// MARK: - Mock Implementation

public final class MockScraperSyncService: ScraperSyncServiceProtocol, @unchecked Sendable {

    public var simulatedError: Error?
    public var mockStatusUpdate: ApplicationStatus? = .inReview

    public init() {}

    public func syncApplicationStatus(applicationId: String, jobId: String) async throws -> ApplicationStatus {
        if let error = simulatedError { throw error }
        try await Task.sleep(for: .milliseconds(500))
        return mockStatusUpdate ?? .applied
    }

    public func batchSync(userId: String) async throws -> [JobApplication] {
        if let error = simulatedError { throw error }
        try await Task.sleep(for: .milliseconds(800))

        // Return a sample set of applications with varied statuses
        return [
            JobApplication(
                jobId: "mock-1",
                jobTitle: "Software Developer",
                companyName: "Google",
                userId: userId,
                resumeURL: "",
                status: .inReview,
                lastSyncedAt: Date(),
                syncStatus: .synced
            ),
            JobApplication(
                jobId: "mock-2",
                jobTitle: "Embedded Systems Intern",
                companyName: "Texas Instruments",
                userId: userId,
                resumeURL: "",
                status: .applied,
                lastSyncedAt: Date().addingTimeInterval(-8 * 24 * 3600),
                syncStatus: .stale
            ),
            JobApplication(
                jobId: "mock-3",
                jobTitle: "Data Engineer",
                companyName: "Snowflake",
                userId: userId,
                resumeURL: "",
                status: .shortlisted,
                lastSyncedAt: Date(),
                syncStatus: .synced
            )
        ]
    }

    public func manualCheckURL(for jobId: String) -> String? {
        return "https://careers.example.com/job/\(jobId)"
    }
}
