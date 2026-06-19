// ApplicationService.swift
// RemoteRecruit

import Foundation
import FirebaseFirestore

// MARK: - Application Service

/// Manages job application CRUD operations in Firestore.
@MainActor
public final class ApplicationService {

    // MARK: - Singleton

    public static let shared = ApplicationService()

    // MARK: - Properties

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Submit Application (Legacy)

    /// Writes a new application document to the `applications` collection.
    /// - Parameters:
    ///   - jobId: The ID of the job being applied to.
    ///   - userId: The Firebase Auth UID of the applicant.
    ///   - resumeURL: The download URL of the user's resume.
    ///   - completion: Returns `true` on success, `false` on failure.
    public func submitApplication(
        jobId: String,
        userId: String,
        resumeURL: String,
        completion: @escaping (Bool) -> Void
    ) {
        let application = JobApplication(
            jobId: jobId,
            userId: userId,
            resumeURL: resumeURL
        )

        do {
            let data = try Firestore.Encoder().encode(application)

            db.collection("applications")
                .document(application.id)
                .setData(data) { error in
                    if let error = error {
                        print("[ApplicationService] Submit failed: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        completion(true)
                    }
                }
        } catch {
            print("[ApplicationService] Encoding failed: \(error.localizedDescription)")
            completion(false)
        }
    }

    // MARK: - Check Existing Application (Legacy)

    /// Checks whether the user has already applied for a given job.
    public func checkExistingApplication(
        jobId: String,
        userId: String,
        completion: @escaping (Bool) -> Void
    ) {
        db.collection("applications")
            .whereField("jobId", isEqualTo: jobId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("[ApplicationService] Check failed: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                let exists = snapshot?.documents.isEmpty == false
                completion(exists)
            }
    }

    // MARK: - Async/Await API

    /// Fetches all applications for a user, ordered by most recent first.
    public func fetchApplications(userId: String) async throws -> [JobApplication] {
        let snapshot = try await db.collection("applications")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: JobApplication.self)
        }
    }

    /// Fetches applications filtered by a specific status.
    public func fetchApplications(userId: String, status: ApplicationStatus) async throws -> [JobApplication] {
        let snapshot = try await db.collection("applications")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: status.rawValue)
            .order(by: "timestamp", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: JobApplication.self)
        }
    }

    /// Updates the status of an application.
    public func updateApplicationStatus(applicationId: String, status: ApplicationStatus) async throws {
 try await db.collection("applications").document(applicationId).updateData([
            "status": status.rawValue,
            "lastSyncedAt": FieldValue.serverTimestamp(),
            "syncStatus": SyncStatus.synced.rawValue
        ])
    }

    /// Updates the sync status and timestamp of an application.
    public func updateSyncStatus(applicationId: String, syncStatus: SyncStatus) async throws {
        try await db.collection("applications").document(applicationId).updateData([
            "syncStatus": syncStatus.rawValue,
            "lastSyncedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Checks if a user has already applied for a given job (async version).
    public func hasExistingApplication(jobId: String, userId: String) async throws -> Bool {
        let snapshot = try await db.collection("applications")
            .whereField("jobId", isEqualTo: jobId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        return !snapshot.documents.isEmpty
    }
}
