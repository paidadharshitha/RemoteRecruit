// BackgroundFirestoreActor.swift
// RemoteRecruit

import Foundation
import FirebaseFirestore

// MARK: - Background Firestore Actor

/// A dedicated actor that performs all Firestore write operations **off the main thread**.
/// This keeps the UI fully responsive while profile data is persisted in the background.
///
/// Usage:
/// ```swift
/// let result = await BackgroundFirestoreActor.shared.saveProfile(profile)
/// // result is .saved or .failed(Error)
/// ```
@globalActor
public enum FirestoreWriteActor {
    public static let shared = FirestoreWriter()
}

/// The actual actor that isolates Firestore write operations.
public actor FirestoreWriter: Sendable {
    private let db = Firestore.firestore()

    /// Maximum silent retries on transient failures.
    private let maxRetries = 2

    /// Delay between retries (exponential back-off).
    private func retryDelay(for attempt: Int) -> Duration {
        let seconds = pow(2.0, Double(attempt))
        return .seconds(seconds)
    }

    // MARK: - Write Profile (full document)

    /// Writes (or merges) a full `UserProfile` document with silent retry on failure.
    public func saveProfile(_ profile: UserProfile) async -> ProfileWriteResult {
        guard !profile.userId.isEmpty else {
            return .failed(FirestoreServiceError.missingUserID)
        }

        return await writeWithRetry(maxAttempts: maxRetries) { db in
            try await db.collection("users")
                .document(profile.userId)
                .setData([
                    "name": profile.name,
                    "email": profile.email,
                    "college": profile.college,
                    "phone": profile.phone,
                    "domain": profile.domain,
                    "experienceLevel": profile.experienceLevel,
                    "yearOfStudy": profile.yearOfStudy ?? NSNull(),
                    "yearsOfExperience": profile.yearsOfExperience ?? NSNull(),
                    "resumeURL": profile.resumeURL ?? NSNull(),
                    "skills": profile.skills,
                    "portfolioLink": profile.portfolioLink,
                    "batchYear": profile.batchYear ?? NSNull(),
                    "academicBranch": profile.academicBranch?.rawValue ?? NSNull(),
                    "preferredRoles": profile.preferredRoles.map { $0.rawValue }
                ], merge: true)
        }
    }

    // MARK: - Update Specific Fields

    /// Merges selected fields into an existing user profile document with silent retry.
    public func updateFields(userId: String, fields: [String: Any]) async -> ProfileWriteResult {
        guard !userId.isEmpty else {
            return .failed(FirestoreServiceError.missingUserID)
        }

        return await writeWithRetry(maxAttempts: maxRetries) { db in
            try await db.collection("users")
                .document(userId)
                .setData(fields, merge: true)
        }
    }

    // MARK: - Retry Logic

    /// Executes a write closure with up to `maxAttempts` attempts, returning the result.
    private func writeWithRetry(
        maxAttempts: Int,
        _ operation: @Sendable (Firestore) async throws -> Void
    ) async -> ProfileWriteResult {
        for attempt in 0..<maxAttempts {
            do {
                try await operation(db)
                return .saved
            } catch {
                // If this is not the last attempt, wait before retrying
                if attempt < maxAttempts - 1 {
                    print("[FirestoreWriter] ⚠️ Write failed (attempt \(attempt + 1)/\(maxAttempts)): \(error.localizedDescription). Retrying in \(retryDelay(for: attempt))...")
                    try? await Task.sleep(for: retryDelay(for: attempt))
                } else {
                    print("[FirestoreWriter] ❌ Write failed after \(maxAttempts) attempts: \(error.localizedDescription)")
                    return .failed(error)
                }
            }
        }
        return .failed(FirestoreServiceError.missingUserID) // Unreachable fallback
    }
}

// MARK: - Write Result

/// Represents the outcome of a background Firestore write operation.
public enum ProfileWriteResult: Sendable {
    case saved
    case failed(Error)

    /// Whether the write succeeded.
    public var isSuccess: Bool {
        if case .saved = self { return true }
        return false
    }
}
