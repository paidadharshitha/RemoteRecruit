// JobService.swift
// RemoteRecruit

import Foundation

// MARK: - View State

/// Explicit state machine for view rendering — eliminates ambiguous optional-based states.
enum ViewState<T: Equatable>: Equatable {
    case idle
    case loading
    case success(data: T)
    case empty
    case error(message: String)

    var data: T? {
        if case .success(let data) = self { return data }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }

    // MARK: Equatable

    static func == (lhs: ViewState, rhs: ViewState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.empty, .empty):
            return true
        case (.success(let l), .success(let r)):
            return l == r
        case (.error(let l), .error(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - Service Error

/// Domain-specific errors for the service layer.
enum JobServiceError: LocalizedError, Equatable, Sendable {
    case networkUnavailable
    case serverError(statusCode: Int)
    case decodingError
    case unauthorized
    case custom(message: String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network is unavailable. Please check your connection."
        case .serverError(let code):
            return "Server error (HTTP \(code)). Please try again later."
        case .decodingError:
            return "Failed to parse the response from the server."
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .custom(let message):
            return message
        }
    }
}

// MARK: - Protocol

protocol JobServiceProtocol: Sendable {
    func fetchJobs() async throws -> [Job]
    func fetchJob(by id: UUID) async throws -> Job
}

// MARK: - URLSession Abstraction

protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

// MARK: - Remote Implementation

final class RemoteJobService: JobServiceProtocol {

    private let baseURL: URL
    private let session: URLSessionProtocol

    init(
        baseURL: URL = URL(string: "https://api.remoterecruit.com/v1")!,
        session: URLSessionProtocol = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchJobs() async throws -> [Job] {
        let request = buildRequest(path: "/jobs")
        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Job].self, from: data)
        } catch is DecodingError {
            throw JobServiceError.decodingError
        }
    }

    func fetchJob(by id: UUID) async throws -> Job {
        let request = buildRequest(path: "/jobs/\(id.uuidString.lowercased())")
        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Job.self, from: data)
        } catch is DecodingError {
            throw JobServiceError.decodingError
        }
    }

    // MARK: Private

    private func buildRequest(path: String) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "remote", value: "true")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        return request
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw JobServiceError.networkUnavailable
        }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw JobServiceError.unauthorized
        default:
            throw JobServiceError.serverError(statusCode: http.statusCode)
        }
    }
}
