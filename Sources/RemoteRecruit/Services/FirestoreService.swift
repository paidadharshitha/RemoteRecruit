// FirestoreService.swift
// RemoteRecruit

import Foundation
import FirebaseFirestore

// MARK: - Firestore Service

/// Handles reading and writing user profile documents in Firestore.
@MainActor
public final class FirestoreService {

    // MARK: - Singleton

    public static let shared = FirestoreService()

    // MARK: - Properties

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Save Profile

    /// Writes (or overwrites) a `UserProfile` document for the given user.
    /// - Parameter profile: The profile data to persist.
    /// - Throws: Any Firestore write error.
    public func saveUserProfile(profile: UserProfile) async throws {
        guard !profile.userId.isEmpty else {
            throw FirestoreServiceError.missingUserID
        }

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
                "preferredRoles": profile.preferredRoles.map { $0.rawValue },
                "workExperience": try FirestoreEncoder().encode(profile.workExperience),
                "projects": try FirestoreEncoder().encode(profile.projects)
 ], merge: true)
    }

    // MARK: - Update Profile Fields

    /// Merges selected fields into an existing user profile document.
    /// Only the provided keys are written — untouched fields are preserved.
    ///
    /// - Parameters:
    ///   - userId: The Firebase Auth UID.
    ///   - fields: Dictionary of field names to values (must be Firestore-compatible types).
    /// - Throws: Firestore write errors.
    public func updateProfileFields(userId: String, fields: [String: Any]) async throws {
        guard !userId.isEmpty else {
            throw FirestoreServiceError.missingUserID
        }

        try await db.collection("users")
            .document(userId)
            .setData(fields, merge: true)
    }

    // MARK: - Fetch Profile

    /// Retrieves the stored profile for a given user ID.
    /// - Parameter userId: The Firebase Auth UID of the user.
    /// - Returns: A `UserProfile` if the document exists.
    /// - Throws: Firestore read errors or a `.documentNotFound` error.
    public func fetchUserProfile(userId: String) async throws -> UserProfile {
        guard !userId.isEmpty else {
            throw FirestoreServiceError.missingUserID
        }

        let snapshot = try await db.collection("users")
            .document(userId)
            .getDocument()

        guard snapshot.exists else {
            throw FirestoreServiceError.documentNotFound
        }

        let data = snapshot.data()

        let batchYear = data?["batchYear"] as? Int
        let yearOfStudy = data?["yearOfStudy"] as? Int
        let yearsOfExperience = data?["yearsOfExperience"] as? Int
        let academicBranch: AcademicDomain? = (data?["academicBranch"] as? String).flatMap { AcademicDomain(rawValue: $0) }
        let preferredRoles: [TechnicalRole] = (data?["preferredRoles"] as? [String])?.compactMap { TechnicalRole(rawValue: $0) } ?? []

        let workExperience: [WorkExperience]
        if let weData = data?["workExperience"] as? [[String: Any]] {
            workExperience = weData.compactMap { try? FirestoreDecoder().decode(WorkExperience.self, from: $0) }
        } else {
            workExperience = []
        }

        let projects: [Project]
        if let projData = data?["projects"] as? [[String: Any]] {
            projects = projData.compactMap { try? FirestoreDecoder().decode(Project.self, from: $0) }
        } else {
            projects = []
        }

        return UserProfile(
            name: data?["name"] as? String ?? "",
            userId: userId,
            email: data?["email"] as? String ?? "",
            college: data?["college"] as? String ?? "",
            phone: data?["phone"] as? String ?? "",
            domain: data?["domain"] as? String ?? "",
            experienceLevel: data?["experienceLevel"] as? String ?? "",
            yearOfStudy: yearOfStudy,
            yearsOfExperience: yearsOfExperience,
            resumeURL: data?["resumeURL"] as? String,
            skills: data?["skills"] as? [String] ?? [],
            projects: projects,
            workExperience: workExperience,
            portfolioLink: data?["portfolioLink"] as? String ?? "",
            batchYear: batchYear,
            academicBranch: academicBranch,
            preferredRoles: preferredRoles
        )
    }

    // MARK: - Fetch Jobs by Domain

    /// Fetches job documents filtered by domain. Pass `nil` to return all jobs.
    /// - Parameter domain: The domain to filter by, or `nil` for all jobs.
    /// - Returns: An array of `Job` matching the given domain.
    /// - Throws: Any Firestore read error.
    public func fetchJobs(for domain: String?) async throws -> [Job] {
        let query: Query

        if let domain, !domain.isEmpty {
            query = db.collection("jobs").whereField("domain", isEqualTo: domain)
        } else {
            query = db.collection("jobs")
        }

        let snapshot = try await query.getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Job.self)
        }
    }

    // MARK: - Fetch Jobs Matching Skills

    /// Fetches all jobs from the 'jobs' collection, then client-side filters
    /// to return only jobs whose `tags` array contains at least one of the given skills.
    /// Falls back to domain-based filtering if no skill matches are found.
    ///
    /// - Parameters:
    ///   - skills: The user's skills extracted from their resume.
    ///   - domain: The user's preferred domain (used as fallback).
    /// - Returns: An array of `Job` matching the user's skillset.
    public func fetchJobsMatchingSkills(_ skills: [String], fallbackDomain domain: String?) async throws -> [Job] {
        // Fetch all jobs (or domain-filtered if domain is set)
        let allJobs = try await fetchJobs(for: domain)

        guard !skills.isEmpty else { return allJobs }

        // Client-side filter: jobs whose tags contain any user skill (case-insensitive)
        let lowercasedSkills = skills.map { $0.lowercased() }
        let matched = allJobs.filter { job in
            job.tags.contains { tag in
                lowercasedSkills.contains { tag.lowercased().contains($0) || $0.contains(tag.lowercased()) }
            }
        }

        // If no skill matches, fall back to domain-filtered results (already in allJobs)
        return matched.isEmpty ? allJobs : matched
    }
}

// MARK: - Errors

public enum FirestoreServiceError: LocalizedError, Sendable {
    case missingUserID
    case documentNotFound

    public var errorDescription: String? {
        switch self {
        case .missingUserID:
            return "User ID is required to perform this operation."
        case .documentNotFound:
            return "No profile document found for this user."
        }
    }
}

// MARK: - Firestore Encoder/Decoder Helpers

/// Encodes a `Codable` value to a Firestore-compatible `[String: Any]` dictionary.
struct FirestoreEncoder {
    func encode<T: Codable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return firestoreCompatible(dict)
    }

    func encode<T: Codable>(_ values: [T]) throws -> [[String: Any]] {
        let data = try JSONEncoder().encode(values)
        guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return array.map { firestoreCompatible($0) }
    }

    /// Converts NSNull values and ensures Firestore-compatible types.
    private func firestoreCompatible(_ dict: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in dict {
            result[key] = convert(value)
        }
        return result
    }

    private func convert(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            return firestoreCompatible(dict)
        }
        if let array = value as? [Any] {
            return array.map { convert($0) }
        }
        if value is NSNull {
            return NSNull()
        }
        return value
    }
}

/// Decodes a Firestore `[String: Any]` dictionary to a `Codable` type.
struct FirestoreDecoder {
    func decode<T: Codable>(_ type: T.Type, from dict: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
