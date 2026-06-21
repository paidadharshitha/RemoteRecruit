// RecommendationEngine.swift
// RemoteRecruit

import Foundation

// MARK: - Protocol

public protocol Recommending: Sendable {
    /// Generates personalized job recommendations based on user profile.
    func recommend(
        jobs: [Job],
        userSkills: [String],
        preferredDomains: [JobDomain],
        experienceLevel: ExperienceLevel?
    ) -> [RecommendedJob]
}

// MARK: - Implementation

public struct RecommendationEngine: Recommending {

    public init() {}

    // MARK: - Scoring Weights

    private enum Weights {
        static let skillMatch: Double = 0.40
        static let domainMatch: Double = 0.35
        static let experienceMatch: Double = 0.25
    }

    // MARK: - Relevance Tiers

    private static func relevanceLabel(for score: Int) -> String {
        switch score {
        case 90...: return "95% Relevant"
        case 70..<90: return "80% Relevant"
        default: return "60% Relevant"
        }
    }

    // MARK: - Public API

    public func recommend(
        jobs: [Job],
        userSkills: [String],
        preferredDomains: [JobDomain],
        experienceLevel: ExperienceLevel?
    ) -> [RecommendedJob] {
        var scored: [RecommendedJob] = []

        for job in jobs {
            let score = calculateRelevance(
                job: job,
                userSkills: userSkills,
                preferredDomains: preferredDomains,
                experienceLevel: experienceLevel
            )
            scored.append(RecommendedJob(
                job: job,
                relevanceScore: score,
                relevanceLabel: Self.relevanceLabel(for: score)
            ))
        }

        // Sort by highest relevance first
        return scored.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    // MARK: - Private

    private func calculateRelevance(
        job: Job,
        userSkills: [String],
        preferredDomains: [JobDomain],
        experienceLevel: ExperienceLevel?
    ) -> Int {
        let skillScore = skillMatchScore(userSkills: userSkills, job: job)
        let domainScore = domainMatchScore(preferredDomains: preferredDomains, job: job)
        let experienceScore = experienceMatchScore(preferredLevel: experienceLevel, job: job)

        let total = skillScore * Weights.skillMatch
            + domainScore * Weights.domainMatch
            + experienceScore * Weights.experienceMatch

        return Int(total.rounded())
    }

    /// Score based on skill overlap (0–100).
    private func skillMatchScore(userSkills: [String], job: Job) -> Double {
        guard !userSkills.isEmpty else { return 0 }
        let normalizedUser = userSkills.map { $0.lowercased() }
        let normalizedJob = job.tags.map { $0.lowercased() }

        let matchCount = normalizedUser.filter { userSkill in
            normalizedJob.contains { jobSkill in
                jobSkill.contains(userSkill) || userSkill.contains(jobSkill)
            }
        }.count

        return (Double(matchCount) / Double(normalizedJob.count)) * 100.0
    }

    /// Score based on domain match (100 if preferred, 0 if not).
    private func domainMatchScore(preferredDomains: [JobDomain], job: Job) -> Double {
        guard !preferredDomains.isEmpty else { return 50.0 } // No preference = neutral
        return preferredDomains.contains(job.domain) ? 100.0 : 0.0
    }

    /// Score based on experience level match (100 if match, 0 if not).
    private func experienceMatchScore(preferredLevel: ExperienceLevel?, job: Job) -> Double {
        guard let level = preferredLevel else { return 50.0 } // No preference = neutral
        return job.experienceLevel == level ? 100.0 : 0.0
    }
}
