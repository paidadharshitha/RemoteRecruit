// MockJobService.swift
// RemoteRecruit

import Foundation

// MARK: - Mock Job Service

/// A mock implementation used for SwiftUI previews and standalone app demos.
/// Returns `MockData.sampleJobs` on fetch, optionally simulates errors.
public final class MockJobService: JobServiceProtocol, @unchecked Sendable {

    /// When non-nil, fetches will throw this error instead of returning data.
    public var simulatedError: Error?

    public init() {}

    public func fetchJobs(for domain: String? = nil) async throws -> [Job] {
        if let error = simulatedError {
            throw error
        }
        // Simulate network delay for realistic UI transition
        try await Task.sleep(for: .milliseconds(500))

        if let domain, !domain.isEmpty {
            return MockData.sampleJobs.filter { $0.domain.rawValue == domain }
        }
        return MockData.sampleJobs
    }

    public func fetchJob(by id: String) async throws -> Job {
        if let error = simulatedError {
            throw error
        }
        try await Task.sleep(for: .milliseconds(100))
        guard let job = MockData.sampleJobs.first(where: { $0.id == id }) else {
            throw JobServiceError.custom(message: "Job not found.")
        }
        return job
    }
}
