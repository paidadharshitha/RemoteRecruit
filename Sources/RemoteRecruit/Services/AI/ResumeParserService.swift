// ResumeParserService.swift
// RemoteRecruit

import Foundation

// MARK: - Protocol

/// Protocol for resume parsing services, enabling DI and testability.
public protocol ResumeParsing: Sendable {
    /// Parses resume text and returns structured user data.
    /// - Parameter text: Raw text extracted from a PDF resume.
    /// - Returns: A `ParsedResume` with extracted fields.
    func parse(text: String) async throws -> ParsedResume
}

// MARK: - Errors

public enum ResumeParserError: LocalizedError, Equatable, Sendable {
    case missingAPIKey
    case emptyText
    case invalidResponse
    case decodingFailed(String)
    case networkError(String)
    case invalidAPIKey
    case quotaExceeded

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is not configured."
        case .emptyText:
            return "Resume text is empty. Please upload a valid PDF."
        case .invalidResponse:
            return "The AI returned an empty or invalid response."
        case .decodingFailed(let detail):
            return "Failed to parse AI response: \(detail)"
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .invalidAPIKey:
            return "Invalid API key. Check your GeminiAPIKey in Config.plist."
        case .quotaExceeded:
            return "API quota exceeded. Wait a moment or enable billing at ai.google.dev."
        }
    }
}

// MARK: - Gemini Implementation

/// Concrete implementation of `ResumeParsing` powered by Gemini 1.5 Flash.
/// Sends extracted PDF text to the Gemini API with a JSON schema prompt and
/// returns structured `ParsedResume` data.
public final class GeminiResumeParser: ResumeParsing {

    private let apiKey: String
    private let session: URLSessionProtocol
    private let model = "gemini-2.5-flash"

    public init(
        apiKey: String,
        session: URLSessionProtocol = URLSession.shared
    ) {
        self.apiKey = apiKey
        self.session = session
    }

    public func parse(text: String) async throws -> ParsedResume {
        // ── 1. Validate inputs ─────────────────────────────────────────────
        guard !apiKey.isEmpty else {
            print("[ResumeParser] ❌ API key is missing or empty.")
            throw ResumeParserError.missingAPIKey
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            print("[ResumeParser] ❌ Resume text is empty.")
            throw ResumeParserError.emptyText
        }

        // ── 2. Build request ───────────────────────────────────────────────
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            fatalError("[ResumeParser] Malformed API URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        // ── 3. System instruction (strict JSON prompt) ─────────────────────
        let systemInstruction = """
        You are a professional Resume Parser. Extract the following information \
        and return ONLY a clean JSON object without any markdown or extra text: \
        {"name": "String", "email": "String", "phone": "String", "skills": ["String"], "experience": "String", "domain": "String", "portfolioLink": "String", "projects": [{"title": "String", "description": "String", "technologies": ["String"], "role": "String", "duration": "String"}], "workExperience": [{"company": "String", "role": "String", "duration": "String", "description": "String"}]}. \
        For "experience" provide a short summary like "Fresher" or "3 years". \
        For "projects", extract each project with its title, a brief description, technologies used, the person's role, and duration. \
        For "workExperience", extract each job with company name, role/title, duration, and a brief description of responsibilities. \
        If information is missing, use "" for strings and [] for arrays.
        """

        let body: [String: Any] = [
            "contents": [[
                "parts": [["text": trimmed]]
            ]] as [[String: Any]],
            "systemInstruction": [
                "parts": [["text": systemInstruction]]
            ] as [String: Any],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.1
            ] as [String: Any]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // ── 4. Send request ────────────────────────────────────────────────
        print("[ResumeParser] 📤 Sending resume text to Gemini (\(model))…")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("[ResumeParser] ❌ Network request failed: \(error.localizedDescription)")
            throw ResumeParserError.networkError(error.localizedDescription)
        }

        // ── 5. Handle HTTP status ──────────────────────────────────────────
        guard let http = response as? HTTPURLResponse else {
            print("[ResumeParser] ❌ Invalid response (not HTTP).")
            throw ResumeParserError.networkError("Invalid server response.")
        }

        switch http.statusCode {
        case 200...299:
            break // success
        case 400:
            print("[ResumeParser] ❌ HTTP 400 — Bad request. The prompt or payload may be malformed.")
            throw ResumeParserError.networkError("Bad request (HTTP 400).")
        case 401, 403:
            print("[ResumeParser] ❌ HTTP \(http.statusCode) — Invalid API key or access denied. Check your GeminiAPIKey in Config.plist.")
            throw ResumeParserError.invalidAPIKey
        case 429:
            print("[ResumeParser] ⚠️  HTTP 429 — Quota exceeded. Free tier limit reached. Enable billing at ai.google.dev or wait for quota reset.")
            throw ResumeParserError.quotaExceeded
        case 404:
            print("[ResumeParser] ❌ HTTP 404 — Model '\(model)' not found. Check that the model name is correct and available in your region.")
            throw ResumeParserError.networkError("Model '\(model)' not found (HTTP 404).")
        default:
            print("[ResumeParser] ❌ HTTP \(http.statusCode) — Unexpected error.")
            throw ResumeParserError.networkError("Unexpected HTTP \(http.statusCode).")
        }

        // ── 6. Decode Gemini envelope ──────────────────────────────────────
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

        let envelope: GeminiEnvelope
        do {
            envelope = try JSONDecoder().decode(GeminiEnvelope.self, from: data)
        } catch {
            print("[ResumeParser] ❌ Failed to decode Gemini envelope: \(error.localizedDescription)")
            throw ResumeParserError.decodingFailed("Failed to decode Gemini envelope.")
        }

        guard let responseText = envelope.candidates.first?.content.parts.first?.text,
              !responseText.isEmpty else {
            print("[ResumeParser] ❌ Gemini returned an empty response.")
            throw ResumeParserError.invalidResponse
        }

        // ── 7. Clean markdown fences from response ─────────────────────────
        let cleanedJSON = cleanMarkdownFences(from: responseText)

        // ── 8. Decode into ParsedResume ────────────────────────────────────
        let parsed: ParsedResume
        do {
            parsed = try JSONDecoder().decode(ParsedResume.self, from: Data(cleanedJSON.utf8))
        } catch {
            print("[ResumeParser] ❌ JSON decode failed: \(error.localizedDescription)")
            print("[ResumeParser] 📄 Raw cleaned response:\n\(cleanedJSON.prefix(500))")
            throw ResumeParserError.decodingFailed(error.localizedDescription)
        }

        print("[ResumeParser] ✅ Parsed resume: \(parsed.name) — \(parsed.skills.count) skills, domain: \(parsed.domain)")
        return parsed
    }

    // MARK: - Markdown Fence Cleaner

    /// Strips ```json ... ``` fences and any surrounding whitespace
    /// that Gemini may include despite the `responseMimeType: application/json` setting.
    private func cleanMarkdownFences(from raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove opening fence: ```json or ```
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }

        // Remove closing fence: ```
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Mock Implementation

/// Mock parser for UI testing and previews. Returns hardcoded parsed data.
public final class MockResumeParser: ResumeParsing, @unchecked Sendable {

    public var simulatedError: Error?
    public var delay: Duration = .milliseconds(800)

    public init() {}

    public func parse(text: String) async throws -> ParsedResume {
        if let error = simulatedError { throw error }
        try await Task.sleep(for: delay)

        return ParsedResume(
            name: "Jane Doe",
            email: "jane.doe@example.com",
            skills: ["Swift", "SwiftUI", "UIKit", "Combine", "Core Data", "Firebase"],
            experience: "Fresher",
            phone: "+1 555-123-4567",
            domain: "iOS Developer",
            portfolioLink: "https://janedoe.dev",
            projects: [
                Project(title: "TaskFlow App", description: "A task management app with real-time sync and push notifications.", technologies: ["Swift", "SwiftUI", "Firebase"], role: "Solo Developer", duration: "3 months"),
                Project(title: "WeatherKit UI", description: "Beautiful weather dashboard with animated backgrounds and location search.", technologies: ["SwiftUI", "Combine", "WeatherKit"], role: "Lead Developer", duration: "2 months")
            ],
            workExperience: [
                WorkExperience(company: "TechCorp", role: "iOS Developer Intern", duration: "Jun 2024 – Sep 2024", description: "Built features for the customer-facing iOS app using SwiftUI and async/await.")
            ]
        )
    }
}
