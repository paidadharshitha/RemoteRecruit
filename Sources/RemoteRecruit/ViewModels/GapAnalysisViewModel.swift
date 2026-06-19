// GapAnalysisViewModel.swift
// RemoteRecruit

import Foundation
import Combine

// MARK: - Gap Analysis Result

/// Represents the gap between a user's skills and a job's requirements.
public struct SkillGap: Identifiable, Hashable {
    public let id: String
    public let skill: String
    public let isMatched: Bool

    public init(skill: String, isMatched: Bool) {
        self.id = UUID().uuidString
        self.skill = skill
        self.isMatched = isMatched
    }
}

/// Aggregated gap analysis result for a single job.
public struct GapAnalysisResult: Equatable {
    public let matchedSkills: [String]
    public let missingSkills: [String]
    public let matchScore: Int // 0–100

    public var gaps: [SkillGap] {
        let matched = matchedSkills.map { SkillGap(skill: $0, isMatched: true) }
        let missing = missingSkills.map { SkillGap(skill: $0, isMatched: false) }
        return matched + missing
    }

    public init(matchedSkills: [String], missingSkills: [String], matchScore: Int) {
        self.matchedSkills = matchedSkills
        self.missingSkills = missingSkills
        self.matchScore = matchScore
    }
}

// MARK: - Gap Analysis State

public enum GapAnalysisState: Equatable {
    case idle
    case analyzing
    case result(GapAnalysisResult)
    case error(String)
}

// MARK: - View Model

@MainActor
public final class GapAnalysisViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var state: GapAnalysisState = .idle

    // MARK: - Private

    private let userSkills: [String]
    private let job: Job

    // MARK: - Init

    public init(userSkills: [String], job: Job) {
        self.userSkills = userSkills
        self.job = job
    }

    // MARK: - Analyze

    public func analyze() async {
        state = .analyzing

        // Simulate brief network delay for UI feedback
        try? await Task.sleep(for: .milliseconds(300))

        let jobKeywords = extractKeywords(from: job)
        let userLower = Set(userSkills.map { $0.lowercased() })

        var matched: [String] = []
        var missing: [String] = []

        for keyword in jobKeywords {
            if userLower.contains(keyword.lowercased()) {
                matched.append(keyword)
            } else {
                missing.append(keyword)
            }
        }

        // Deduplicate and sort
        matched = Array(Set(matched)).sorted()
        missing = Array(Set(missing)).sorted()

        let totalRequired = matched.count + missing.count
        let score = totalRequired > 0 ? Int(Double(matched.count) / Double(totalRequired) * 100) : 0

        let result = GapAnalysisResult(
            matchedSkills: matched,
            missingSkills: missing,
            matchScore: score
        )

        state = .result(result)
    }

    // MARK: - Keyword Extraction

    private func extractKeywords(from job: Job) -> [String] {
        var keywords = Set<String>()

        // Extract from tags
        for tag in job.tags {
            keywords.insert(tag)
        }

        // Extract from domain keywords
        for kw in job.domain.keywords {
            keywords.insert(kw)
        }

        // Extract capitalized words from description (likely tech terms)
        let words = job.jobDescription.components(separatedBy: CharacterSet(charactersIn: " ,.()[]{}:;\"'-/\n\t"))
            .filter { $0.count > 2 && $0.first?.isLetter == true }
        for word in words {
            if word.first?.isUppercase == true {
                keywords.insert(word)
            }
        }

        return Array(keywords)
    }
}
