// AIService.swift
// RemoteRecruit

import Foundation

// MARK: - Protocol

public protocol AIServiceProtocol: Sendable {
    func analyzeResume(_ resumeText: String) async throws -> ATSAnalysisResult
    func analyzeResume(resumeText: String, jobDescription: String) async throws -> ResumeOptimizerResult
}

// MARK: - Errors

public enum AIServiceError: LocalizedError, Equatable, Sendable {
    case missingAPIKey
    case networkUnavailable
    case serverError(statusCode: Int)
    case decodingError
    case emptyResponse
    case requestTimeout

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is not configured."
        case .networkUnavailable:
            return "Network is unavailable. Please check your connection."
        case .serverError(let code):
            return "Gemini server error (HTTP \(code)). Please try again later."
        case .decodingError:
            return "Failed to parse AI analysis response. Try again."
        case .emptyResponse:
            return "The AI returned an empty analysis. Please try again."
        case .requestTimeout:
            return "The request timed out. Please check your connection and try again."
        }
    }
}

// MARK: - Response DTO

/// Decodable shape matching Gemini's structured JSON output for ATS analysis.
private struct GeminiATSResponse: Codable, Sendable {
    let score: Int
    let missingKeywords: [String]
    let suggestions: [String]
}

// MARK: - Gemini Implementation

/// Actor-isolated network client that performs all URLSession work off the main actor,
/// preventing nw_connection_copy_connected_local_endpoint crashes caused by
/// concurrent URLSession usage from Firebase and other services.
private actor GeminiNetworkClient {
    let session: URLSession
    let apiKey: String
    let model: String

    init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model

        let config = URLSessionConfiguration.default
        // Prevent connection drops by waiting for connectivity
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 180
        // Conservative limit — avoids overwhelming the connection pool
        config.httpMaximumConnectionsPerHost = 2
        // Disable connection reuse to prevent stale nw_connection references
        config.httpShouldUsePipelining = false
        self.session = URLSession(configuration: config)
    }

    /// Executes a POST request to the Gemini API with retry + exponential backoff.
    func fetch(request: URLRequest) async throws -> (Data, URLResponse) {
        let maxAttempts = 3
        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                let result = try await session.data(for: request)
                return result
            } catch let error as URLError {
                lastError = mapURLError(error)
                // Retry on transient network issues
                switch error.code {
                case .timedOut, .networkConnectionLost, .notConnectedToInternet,
                     .cannotConnectToHost, .dnsLookupFailed, .secureConnectionFailed:
                    let delay = Duration.milliseconds(500) * Int64(pow(2.0, Double(attempt)))
                    try? await Task.sleep(for: delay)
                    continue
                default:
                    let delay = Duration.milliseconds(300) * Int64(pow(2.0, Double(attempt)))
                    try? await Task.sleep(for: delay)
                    continue
                }
            } catch {
                lastError = error
                let delay = Duration.milliseconds(300) * Int64(pow(2.0, Double(attempt)))
                try? await Task.sleep(for: delay)
            }
        }
        throw lastError ?? AIServiceError.networkUnavailable
    }

    /// Maps URLError codes to domain-specific AIServiceError values.
    private func mapURLError(_ error: URLError) -> AIServiceError {
        switch error.code {
        case .timedOut:
            return .requestTimeout
        case .notConnectedToInternet, .networkConnectionLost:
            return .networkUnavailable
        case .secureConnectionFailed, .cannotConnectToHost, .dnsLookupFailed:
            return .networkUnavailable
        default:
            return .networkUnavailable
        }
    }
}

public final class GeminiAIService: AIServiceProtocol {

    private let apiKey: String
    private let client: GeminiNetworkClient
    private let model = "gemini-2.5-flash"

    public init(
        apiKey: String,
        session: URLSessionProtocol? = nil
    ) {
        self.apiKey = apiKey
        self.client = GeminiNetworkClient(apiKey: apiKey, model: model)
    }

    public func analyzeResume(_ resumeText: String) async throws -> ATSAnalysisResult {
        guard !apiKey.isEmpty else { throw AIServiceError.missingAPIKey }
        guard !resumeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIServiceError.emptyResponse
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw AIServiceError.networkUnavailable
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let systemInstruction = """
        You are an expert ATS (Applicant Tracking System) resume auditor. \
        Analyze the provided resume text and return a strict JSON object with exactly these three keys:

        1. "score": Integer from 0 to 100 representing the overall ATS compatibility rating.
        2. "missingKeywords": Array of strings listing important technical skills, tools, frameworks, \
        or industry keywords that are absent from the resume but commonly expected.
        3. "suggestions": Array of 3 to 5 actionable, specific improvement tips \
        (e.g. "Add a professional summary section", "Include quantifiable achievements").

        Rules:
        - Output ONLY valid JSON, no markdown fences or extra text.
        - score must be between 0 and 100 inclusive.
        - missingKeywords must be non-empty (suggest at least 3 keywords).
        - suggestions must be non-empty (provide 3–5 tips).
        """

        let body: [String: Any] = [
            "contents": [[
                "parts": [["text": resumeText]]
            ]] as [[String: Any]],
            "systemInstruction": [
                "parts": [["text": systemInstruction]]
            ] as [String: Any],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.2
            ] as [String: Any]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await client.fetch(request: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.networkUnavailable }

        guard (200...299).contains(http.statusCode) else {
            throw AIServiceError.serverError(statusCode: http.statusCode)
        }

        // Parse Gemini response envelope
        struct GeminiEnvelope: Codable {
            struct Candidate: Codable {
                struct Content: Codable {
                    struct Part: Codable {
                        let text: String
                    }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        let envelope = try JSONDecoder().decode(GeminiEnvelope.self, from: data)

        guard let text = envelope.candidates.first?.content.parts.first?.text, !text.isEmpty else {
            throw AIServiceError.emptyResponse
        }

        let parsed = try JSONDecoder().decode(GeminiATSResponse.self, from: Data(text.utf8))
        let clampedScore = min(max(parsed.score, 0), 100)

        return ATSAnalysisResult(
            matchPercentage: clampedScore,
            missingKeywords: parsed.missingKeywords,
            suggestions: parsed.suggestions,
            rawResponse: text
        )
    }

    // MARK: - JD-Aware Analysis

    public func analyzeResume(resumeText: String, jobDescription: String) async throws -> ResumeOptimizerResult {
        guard !apiKey.isEmpty else { throw AIServiceError.missingAPIKey }

        let trimmedResume = resumeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedJD = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedResume.isEmpty, !trimmedJD.isEmpty else {
            throw AIServiceError.emptyResponse
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw AIServiceError.networkUnavailable
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90

        let systemInstruction = """
        You are an expert ATS (Applicant Tracking System) resume optimizer and career coach. \
        You will receive a RESUME and a JOB DESCRIPTION. Compare them thoroughly and return a strict JSON object \
        with exactly these keys:

        1. "atsScore": Integer 0-100 — overall ATS compatibility based on keyword density, \
        formatting alignment, and structural match with the JD.
        2. "missingKeywords": Array of strings — important keywords from the JD absent from the resume \
        (skills, tools, frameworks, certifications, industry terms).
        3. "skillGaps": Array of strings — specific skill mismatches (e.g. "JD requires React Native, resume only lists React").
        4. "experienceGaps": Array of strings — experience-level gaps (e.g. "No leadership experience mentioned", \
        "Missing quantifiable achievements").
        5. "suggestions": Array of 3-5 actionable improvement tips.
        6. "optimizedResume": Object with these keys:
           - "name": String — candidate's full name from the resume.
           - "summary": String — a 2-3 sentence professional summary optimized for the JD.
           - "skills": Array of strings — all relevant skills (existing + missing ones woven in naturally).
           - "experience": Array of objects, each with "company", "role", "duration", "bullets" (array of 3-5 strings). \
             Rewrite bullets to emphasize achievements and JD-relevant keywords.
           - "projects": Array of objects, each with "title", "duration", "technologies" (array of strings), \
             "bullets" (array of 3-5 strings). Emphasize JD-relevant technologies.
        7. "aiChanges": Object with these keys:
           - "keywordsAdded": Array of strings — keywords/skills added from the JD that were not in the original resume.
           - "keywordsReplaced": Array of strings — keywords/skills that were rephrased or upgraded (e.g. "Swift" → "Swift 5 + SwiftUI").
           - "sectionChanges": Array of objects, each with "section" (String, e.g. "Summary", "Experience", "Skills", "Projects") \
             and "description" (String, brief explanation of what was changed in that section).
        8. "aiExplanation": String — a concise, 2-3 sentence explanation of what the AI optimized and why, \
             written in a professional tone for the candidate. Mention the ATS score reasoning and key improvements.

        Rules:
        - Output ONLY valid JSON, no markdown fences or extra text.
        - atsScore must be between 0 and 100 inclusive.
        - All arrays must be non-empty.
        - The optimizedResume must be professional, truthful to the original, and ATS-friendly.
        - Do NOT fabricate experience or projects — only rewrite and enhance what exists in the resume.
        - aiChanges must accurately reflect the specific changes you made to the resume.
        - aiExplanation must be a non-empty string providing a clear, human-readable summary of the optimization.
        """

        let userPrompt = """
        ## RESUME:
        \(trimmedResume)

        ## JOB DESCRIPTION:
        \(trimmedJD)
        """

        let body: [String: Any] = [
            "contents": [[
                "parts": [["text": userPrompt]]
            ]] as [[String: Any]],
            "systemInstruction": [
                "parts": [["text": systemInstruction]]
            ] as [String: Any],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.2
            ] as [String: Any]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await client.fetch(request: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.networkUnavailable }

        guard (200...299).contains(http.statusCode) else {
            throw AIServiceError.serverError(statusCode: http.statusCode)
        }

        struct GeminiEnvelope: Codable {
            struct Candidate: Codable {
                struct Content: Codable {
                    struct Part: Codable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        let envelope = try JSONDecoder().decode(GeminiEnvelope.self, from: data)

        guard let text = envelope.candidates.first?.content.parts.first?.text, !text.isEmpty else {
            throw AIServiceError.emptyResponse
        }

        let cleaned = cleanMarkdownFences(from: text)
        let parsed = try JSONDecoder().decode(ResumeOptimizerResult.self, from: Data(cleaned.utf8))
        return parsed
    }

    // MARK: - Markdown Fence Cleaner

    private func cleanMarkdownFences(from raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Mock Implementation

public final class MockAIService: AIServiceProtocol, @unchecked Sendable {

    public var simulatedError: Error?

    public init() {}

    public func analyzeResume(_ resumeText: String) async throws -> ATSAnalysisResult {
        if let error = simulatedError { throw error }
        try await Task.sleep(for: .milliseconds(800))

        return ATSAnalysisResult(
            matchPercentage: 72,
            missingKeywords: [
                "SwiftUI",
                "Combine",
                "CI/CD",
                "Unit Testing",
                "REST APIs"
            ],
            suggestions: [
                "Add a professional summary highlighting your core competencies.",
                "Include quantifiable achievements (e.g. 'Reduced load time by 40%').",
                "Incorporate relevant ATS keywords from the target job description.",
                "Use a clean, single-column format without tables or graphics.",
                "List technical skills in a dedicated section for easy keyword matching."
            ],
            rawResponse: ""
        )
    }

    public func analyzeResume(resumeText: String, jobDescription: String) async throws -> ResumeOptimizerResult {
        if let error = simulatedError { throw error }
        try await Task.sleep(for: .milliseconds(800))

        return ResumeOptimizerResult(
            atsScore: 78,
            missingKeywords: ["SwiftUI", "CI/CD", "Unit Testing", "REST APIs", "Git Flow"],
            skillGaps: [
                "JD requires SwiftUI but resume only lists UIKit",
                "Missing CI/CD pipeline experience (Fastlane, GitHub Actions)",
                "No mention of REST API design or integration testing"
            ],
            experienceGaps: [
                "No quantifiable achievements listed",
                "Missing leadership or mentoring experience",
                "No mention of cross-functional collaboration"
            ],
            suggestions: [
                "Add a professional summary tailored to the iOS Developer role.",
                "Include quantifiable achievements (e.g. 'Improved app launch time by 35%').",
                "Add a dedicated skills section covering SwiftUI, Combine, and CI/CD tools.",
                "Emphasize collaborative projects and code review experience."
            ],
            optimizedResume: OptimizedResume(
                name: "Jane Doe",
                summary: "Results-driven iOS Developer with experience building performant mobile applications using Swift and SwiftUI. Passionate about clean architecture, testable code, and delivering exceptional user experiences.",
                skills: ["Swift", "SwiftUI", "UIKit", "Combine", "Core Data", "Firebase", "CI/CD", "REST APIs", "Unit Testing", "Git Flow"],
                experience: [
                    OptimizedExperienceSection(
                        company: "TechCorp",
                        role: "iOS Developer Intern",
                        duration: "Jun 2024 – Sep 2024",
                        bullets: [
                            "Developed 3 key features for the customer-facing iOS app using SwiftUI and async/await, improving user engagement by 15%.",
                            "Implemented REST API integration with proper error handling and offline support using Core Data caching.",
                            "Collaborated with design and backend teams in 2-week agile sprints, participating in code reviews and sprint planning."
                        ]
                    )
                ],
                projects: [
                    OptimizedProjectSection(
                        title: "TaskFlow App",
                        duration: "3 months",
                        technologies: ["Swift", "SwiftUI", "Firebase", "CI/CD"],
                        bullets: [
                            "Built a real-time task management app with Firebase Firestore sync supporting 500+ concurrent users.",
                            "Implemented push notifications and offline-first architecture using Combine and Core Data.",
                            "Deployed via CI/CD pipeline with automated test runs on every pull request."
                        ]
                    ),
                    OptimizedProjectSection(
                        title: "WeatherKit UI",
                        duration: "2 months",
                        technologies: ["SwiftUI", "Combine", "WeatherKit"],
                        bullets: [
                            "Designed an animated weather dashboard with location search and 7-day forecasts.",
                            "Leveraged Combine for reactive data binding between WeatherKit responses and UI components.",
                            "Achieved 60fps animations using SwiftUI transitions and custom shape rendering."
                        ]
                    )
                ]
            ),
            aiChanges: AIChanges(
                keywordsAdded: ["SwiftUI", "CI/CD", "Unit Testing", "REST APIs", "Git Flow", "Combine"],
                keywordsReplaced: ["UIKit → SwiftUI", "URLSession → REST APIs with async/await"],
                sectionChanges: [
                    SectionChange(section: "Summary", description: "Rewrote to highlight SwiftUI, Combine, and CI/CD experience targeted at the iOS Developer role."),
                    SectionChange(section: "Skills", description: "Added 5 missing skills from JD: SwiftUI, CI/CD, Unit Testing, REST APIs, Git Flow."),
                    SectionChange(section: "Experience", description: "Enhanced bullet points with quantifiable metrics and JD-relevant keywords (15% engagement increase)."),
                    SectionChange(section: "Projects", description: "Added CI/CD and Firebase mentions to project descriptions to match JD requirements.")
                ]
            ),
            aiExplanation: "Your resume scored a 78/100 on ATS compatibility. The main gaps were missing SwiftUI experience and quantifiable achievements. I restructured your summary to emphasize mobile development strengths, added 5 critical keywords from the JD, and enhanced your bullet points with measurable outcomes to improve keyword density and impact."
        )
    }
}
