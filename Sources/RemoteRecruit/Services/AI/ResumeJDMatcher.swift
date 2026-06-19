// ResumeJDMatcher.swift
// RemoteRecruit

import Foundation

// MARK: - Match Result

/// Result of comparing a resume against a job description.
public struct MatchResult: Sendable, Equatable {

    /// Keywords found in the JD that are already present in the resume.
    public let matchedKeywords: [String]

    /// Keywords from the JD that are missing from the resume.
    public let missingKeywords: [String]

    /// Suggested keywords to add to the resume (subset of missing, prioritized).
    public let suggestedAdditions: [String]

    /// Simple match percentage (0-100) based on keyword overlap.
    public let matchScore: Int

    public init(
        matchedKeywords: [String],
        missingKeywords: [String],
        suggestedAdditions: [String],
        matchScore: Int
    ) {
        self.matchedKeywords = matchedKeywords
        self.missingKeywords = missingKeywords
        self.suggestedAdditions = suggestedAdditions
        self.matchScore = min(max(matchScore, 0), 100)
    }
}

// MARK: - Resume JD Matcher

/// Extracts keywords from a job description and matches them against resume text.
/// Uses local TF-IDF-like extraction with common English stop-word filtering.
public enum ResumeJDMatcher {

    // MARK: - Common English Stop Words

    private static let stopWords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for",
        "of", "with", "by", "from", "as", "is", "was", "are", "were", "been",
        "be", "have", "has", "had", "do", "does", "did", "will", "would",
        "could", "should", "may", "might", "shall", "can", "need", "dare",
        "ought", "used", "it", "its", "this", "that", "these", "those",
        "i", "me", "my", "we", "our", "you", "your", "he", "him", "his",
        "she", "her", "they", "them", "their", "what", "which", "who",
        "when", "where", "how", "all", "each", "every", "both", "few",
        "more", "most", "other", "some", "such", "no", "nor", "not",
        "only", "own", "same", "so", "than", "too", "very", "just",
        "because", "if", "about", "into", "through", "during", "before",
        "after", "above", "below", "between", "under", "again", "further",
        "then", "once", "here", "there", "why", "up", "out", "also",
        "well", "work", "working", "experience", "role", "team", "will",
        "looking", "join", "ability", "strong", "including", "etc",
        "required", "required", "preferred", "plus", "years", "year",
        "minimum", "least", "ideal", "must", "responsible", "responsibilities",
        "description", "requirements", "qualifications", "skills", "job",
        "position", "company", "opportunity", "candidate", "apply", "please",
        "within", "across", "using", "while", "ensure", "help", "make",
        "new", "way", "many", "high", "good", "great", "like", "time",
        "over", "know", "take", "people", "come", "us"
    ]

    // MARK: - Common filler phrases to skip

    private static let fillerPhrases: Set<String> = [
        "equal opportunity employer",
        "reasonable accommodation",
        "visa sponsorship",
        "background check",
        "drug screen",
        "benefits package",
        "competitive salary",
        "comprehensive benefits",
        "health insurance",
        "401k",
        "paid time off",
        "unlimited pto",
        "remote work",
        "hybrid model",
        "office location",
        "office based"
    ]

    // MARK: - Public API

    /// Compares resume text against a job description and returns keyword match analysis.
    /// - Parameters:
    ///   - resumeText: The raw text of the candidate's resume.
    ///   - jdText: The raw text of the job description.
    /// - Returns: A `MatchResult` with matched/missing keywords and a match score.
    public static func matchResumeToJD(
        resumeText: String,
        jdText: String
    ) -> MatchResult {
        let resumeLower = resumeText.lowercased()
        let jdLower = jdText.lowercased()

        let jdKeywords = extractKeywords(from: jdLower)
        let resumeKeywords = extractKeywords(from: resumeLower)

        let resumeKeywordSet = Set(resumeKeywords)

        let matched = jdKeywords.filter { resumeKeywordSet.contains($0) }
        let missing = jdKeywords.filter { !resumeKeywordSet.contains($0) }

        // Prioritize: technical terms (multi-word or longer words) are more valuable
        let suggestedAdditions = missing
            .sorted { $0.count > $1.count }

        let matchScore: Int
        if jdKeywords.isEmpty {
            matchScore = 0
        } else {
            matchScore = Int(Double(matched.count) / Double(jdKeywords.count) * 100)
        }

        return MatchResult(
            matchedKeywords: matched,
            missingKeywords: missing,
            suggestedAdditions: Array(suggestedAdditions.prefix(20)),
            matchScore: matchScore
        )
    }

    // MARK: - Keyword Extraction

    /// Extracts meaningful keywords from text using frequency analysis and stop-word filtering.
    /// Returns multi-word technical terms (e.g. "machine learning") when detected.
    static func extractKeywords(from text: String) -> [String] {
        var keywords: [String] = []
        var seen = Set<String>()

        // Extract multi-word technical terms first (2-3 word phrases)
        let multiWordTerms = extractMultiWordTerms(from: text)
        for term in multiWordTerms {
            if !seen.contains(term) {
                keywords.append(term)
                seen.insert(term)
            }
        }

        // Extract single-word keywords
        let words = tokenize(text)
        var frequencies: [String: Int] = [:]

        for word in words {
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            guard clean.count >= 2, !stopWords.contains(clean) else { continue }
            frequencies[clean, default: 0] += 1
        }

        // Sort by frequency — terms appearing 2+ times are likely important
        let sortedWords = frequencies
            .filter { $0.value >= 1 }
            .sorted { $0.value > $1.value }

        for (word, _) in sortedWords {
            if !seen.contains(word) {
                keywords.append(word)
                seen.insert(word)
            }
        }

        return keywords
    }

    // MARK: - Multi-Word Term Extraction

    /// Detects common technical multi-word terms (2-3 words) in the text.
    private static func extractMultiWordTerms(from text: String) -> [String] {
        // Common technical compound terms to look for
        let patterns: [String] = [
            // Languages & Frameworks
            "machine learning", "deep learning", "natural language processing",
            "computer vision", "data science", "data engineering", "data analysis",
            "software engineering", "full stack", "front end", "back end",
            "project management", "product management", "continuous integration",
            "continuous deployment", "ci cd", "ci/cd",
            "unit testing", "integration testing", "end to end", "e2e testing",
            "cross functional", "code review", "pull request",
            // Cloud & DevOps
            "cloud computing", "cloud infrastructure", "cloud native",
            "amazon web services", "google cloud", "microsoft azure",
            "distributed systems", "microservices architecture",
            "kubernetes", "docker container", "container orchestration",
            // Mobile
            "react native", "swiftui", "uikit", "core data",
            "async await", "grand central dispatch",
            "push notifications", "rest api", "rest apis", "graphql api",
            "objective c", "flutter dart",
            // Data
            "big data", "data pipeline", "data warehouse", "data lake",
            "etl pipeline", "real time", "streaming data",
            "sql database", "nosql database", "relational database",
            // Embedded
            "embedded systems", "real time operating", "real time os",
            "rtos", "plc programming", "scada system", "process control",
            "power systems", "control systems", "vlsi design", "fpga design",
            // Security
            "cyber security", "information security", "network security",
            "agile methodology", "scrum master", "sprint planning"
        ]

        let lowerText = text.lowercased()
        var found: [String] = []

        for pattern in patterns {
            if lowerText.contains(pattern) && !fillerPhrases.contains(pattern) {
                found.append(pattern)
            }
        }

        // Also detect capitalized multi-word terms (e.g. "SwiftUI", "Core Data")
        let capitalPattern = try? NSRegularExpression(
            pattern: "\\b[A-Z][a-z]+(?:\\s+[A-Z][a-z]+)+\\b",
            options: []
        )
        if let regex = capitalPattern {
            let fullRange = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: fullRange)
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let term = text[range].lowercased().trimmingCharacters(in: .whitespaces)
                    guard term.count >= 3, term.count <= 40 else { continue }
                    if !seenStopWords(term) && !found.contains(term) {
                        found.append(term)
                    }
                }
            }
        }

        return found
    }

    // MARK: - Helpers

    /// Tokenizes text into lowercase words, stripping punctuation.
    private static func tokenize(_ text: String) -> [String] {
        return text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Checks if a multi-word term contains only stop words.
    private static func seenStopWords(_ term: String) -> Bool {
        let words = term.components(separatedBy: .whitespaces)
        return words.allSatisfy { stopWords.contains($0) }
    }
}
