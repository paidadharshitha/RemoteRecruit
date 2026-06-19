// ApplyService.swift
// RemoteRecruit

import Foundation
@preconcurrency import FirebaseFirestore

// MARK: - Apply Error

public enum ApplyError: LocalizedError, Equatable, Sendable {
    case noResumeUploaded
    case alreadyApplied
    case networkUnavailable
    case encodingFailed
    case custom(message: String)

    public var errorDescription: String? {
        switch self {
        case .noResumeUploaded:
            return "Please upload your optimized resume before applying."
        case .alreadyApplied:
            return "You have already applied to this position."
        case .networkUnavailable:
            return "Network is unavailable. Please check your connection."
        case .encodingFailed:
            return "Failed to prepare your application. Please try again."
        case .custom(let message):
            return message
        }
    }
}

// MARK: - Apply State

/// Tracks the state of an in-progress apply action for UI binding.
public enum ApplyState: Equatable {
    case idle
    case checkingDuplicate
    case submitting
    case submitted
    case success
    case error(message: String)

    public var isLoading: Bool {
        switch self {
        case .checkingDuplicate, .submitting: return true
        default: return false
        }
    }
}

// MARK: - Protocol

public protocol ApplyServiceProtocol: Sendable {
    /// Checks whether the user has already applied for a given job.
    func hasExistingApplication(jobId: String, userId: String) async throws -> Bool

    /// Submits an application using the user's optimized resume.
    func submitApplication(
        jobId: String,
        jobTitle: String,
        companyName: String,
        userId: String,
        resumeURL: String,
        jobListingURL: String?,
        isEasyApply: Bool,
        coverNote: String?
    ) async throws -> JobApplication
}

// MARK: - Firebase Implementation

public final class FirebaseApplyService: ApplyServiceProtocol, @unchecked Sendable {

    private let db = Firestore.firestore()

    public init() {}

    public func hasExistingApplication(jobId: String, userId: String) async throws -> Bool {
        let snapshot = try await db.collection("applications")
            .whereField("jobId", isEqualTo: jobId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        return !snapshot.documents.isEmpty
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

        let application = JobApplication(
            jobId: jobId,
            jobTitle: jobTitle,
            companyName: companyName,
            userId: userId,
            resumeURL: resumeURL,
            status: .applied,
            lastSyncedAt: Date(),
            syncStatus: .synced,
            jobListingURL: jobListingURL,
            isEasyApply: isEasyApply,
            coverNote: coverNote
        )

        let data = try Firestore.Encoder().encode(application)

        try await db.collection("applications")
            .document(application.id)
            .setData(data)

        return application
    }
}

// MARK: - Mock Implementation

public final class MockApplyService: ApplyServiceProtocol, @unchecked Sendable {

    public var simulatedError: Error?
    private var submittedApplications: [String: Bool] = [:]

    public init() {}

    public func hasExistingApplication(jobId: String, userId: String) async throws -> Bool {
        if let error = simulatedError { throw error }
        try await Task.sleep(for: .milliseconds(200))
        return submittedApplications[jobId] == true
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
        if let error = simulatedError { throw error }
        try await Task.sleep(for: .milliseconds(600))

        let application = JobApplication(
            jobId: jobId,
            jobTitle: jobTitle,
            companyName: companyName,
            userId: userId,
            resumeURL: resumeURL,
            status: .applied,
            lastSyncedAt: Date(),
            syncStatus: .synced,
            jobListingURL: jobListingURL,
            isEasyApply: isEasyApply,
            coverNote: coverNote
        )

        submittedApplications[jobId] = true
        return application
    }
}
