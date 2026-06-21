// RecommendationEngineTests.swift
// RemoteRecruitTests

import XCTest
@testable import RemoteRecruit

// MARK: - RecommendationEngine Tests

final class RecommendationEngineTests: XCTestCase {

    private let engine = RecommendationEngine()

    // MARK: - Helpers

    private func makeJob(
        id: String = "1",
        tags: [String] = ["Swift"],
        domain: JobDomain = .iosDeveloper,
        experienceLevel: ExperienceLevel = .fresher
    ) -> Job {
        Job(
            id: id,
            title: "Engineer",
            companyName: "Acme",
            location: "Remote",
            salaryRange: "$100k",
            jobDescription: "Build things.",
            tags: tags,
            postedDate: Date(),
            domain: domain,
            experienceLevel: experienceLevel
        )
    }

    // MARK: - Perfect Match

    func testPerfectMatchReturnsHighScore() {
        let job = makeJob(
            tags: ["Swift", "SwiftUI", "CoreData"],
            domain: .iosDeveloper,
            experienceLevel: .fresher
        )
        let results = engine.recommend(
            jobs: [job],
            userSkills: ["Swift", "SwiftUI", "CoreData"],
            preferredDomains: [.iosDeveloper],
            experienceLevel: .fresher
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertGreaterThanOrEqual(results[0].relevanceScore, 90)
    }

    // MARK: - Partial Skill Match

    func testPartialSkillMatchReturnsModerateScore() {
        // Job has 4 tags, user matches 2
        let job = makeJob(
            tags: ["Swift", "UIKit", "Combine", "CoreData"],
            domain: .iosDeveloper,
            experienceLevel: .fresher
        )
        let results = engine.recommend(
            jobs: [job],
            userSkills: ["Swift", "UIKit"],
            preferredDomains: [.iosDeveloper],
            experienceLevel: .fresher
        )
        XCTAssertEqual(results.count, 1)
        // 2/4 skill match = 50% skill score
        // 50 * 0.40 + 100 * 0.35 + 100 * 0.25 = 20 + 35 + 25 = 80
        XCTAssertGreaterThanOrEqual(results[0].relevanceScore, 70)
        XCTAssertLessThan(results[0].relevanceScore, 90)
    }

    // MARK: - No Matching Skills

    func testNoMatchingSkillsReturnsLowScore() {
        let job = makeJob(
            tags: ["Python", "Django", "React"],
            domain: .backendEngineer,
            experienceLevel: .fresher
        )
        let results = engine.recommend(
            jobs: [job],
            userSkills: ["Swift", "SwiftUI", "CoreData"],
            preferredDomains: [],
            experienceLevel: nil
        )
        XCTAssertEqual(results.count, 1)
        // 0 skill match + 50% domain neutral + 50% experience neutral
        // 0 * 0.40 + 50 * 0.35 + 50 * 0.25 = 0 + 17.5 + 12.5 = 30
        XCTAssertLessThan(results[0].relevanceScore, 40)
    }

    // MARK: - Domain Match Boosts Score

    func testDomainMatchBoostsScore() {
        let jobMatch = makeJob(
            tags: ["Swift"],
            domain: .iosDeveloper,
            experienceLevel: .fresher
        )
        let jobNoMatch = makeJob(
            id: "2",
            tags: ["Swift"],
            domain: .backendEngineer,
            experienceLevel: .fresher
        )

        let resultsMatch = engine.recommend(
            jobs: [jobMatch],
            userSkills: ["Swift"],
            preferredDomains: [.iosDeveloper],
            experienceLevel: nil
        )
        let resultsNoMatch = engine.recommend(
            jobs: [jobNoMatch],
            userSkills: ["Swift"],
            preferredDomains: [.iosDeveloper],
            experienceLevel: nil
        )
        XCTAssertGreaterThan(resultsMatch[0].relevanceScore, resultsNoMatch[0].relevanceScore)
    }

    // MARK: - No Preferred Domains Returns Neutral Domain Score

    func testNoPreferredDomainsReturnsNeutralScore() {
        let job = makeJob(
            tags: ["Swift"],
            domain: .iosDeveloper,
            experienceLevel: .fresher
        )
        let results = engine.recommend(
            jobs: [job],
            userSkills: ["Swift"],
            preferredDomains: [],
            experienceLevel: nil
        )
        XCTAssertEqual(results.count, 1)
        // skill=100, domain=50(neutral), experience=50(neutral)
        // 100*0.40 + 50*0.35 + 50*0.25 = 40 + 17.5 + 12.5 = 70
        XCTAssertEqual(results[0].relevanceScore, 70)
    }

    // MARK: - Experience Level Match Boosts Score

    func testExperienceLevelMatchBoostsScore() {
        let jobMatch = makeJob(
            tags: ["Swift"],
            domain: .iosDeveloper,
            experienceLevel: .fresher
        )
        let jobNoMatch = makeJob(
            id: "2",
            tags: ["Swift"],
            domain: .iosDeveloper,
            experienceLevel: .experienced
        )

        let resultsMatch = engine.recommend(
            jobs: [jobMatch],
            userSkills: ["Swift"],
            preferredDomains: [],
            experienceLevel: .fresher
        )
        let resultsNoMatch = engine.recommend(
            jobs: [jobNoMatch],
            userSkills: ["Swift"],
            preferredDomains: [],
            experienceLevel: .fresher
        )
        XCTAssertGreaterThan(resultsMatch[0].relevanceScore, resultsNoMatch[0].relevanceScore)
    }

    // MARK: - No Experience Preference Returns Neutral Experience Score

    func testNoExperiencePreferenceReturnsNeutralScore() {
        let job = makeJob(
            tags: ["Swift"],
            domain: .iosDeveloper,
            experienceLevel: .fresher
        )
        let results = engine.recommend(
            jobs: [job],
            userSkills: ["Swift"],
            preferredDomains: [.iosDeveloper],
            experienceLevel: nil
        )
        XCTAssertEqual(results.count, 1)
        // skill=100, domain=100, experience=50(neutral)
        // 100*0.40 + 100*0.35 + 50*0.25 = 40 + 35 + 12.5 = 87.5 → 88
        XCTAssertEqual(results[0].relevanceScore, 88)
    }

    // MARK: - Empty Jobs List

    func testEmptyJobsListReturnsEmptyRecommendations() {
        let results = engine.recommend(
            jobs: [],
            userSkills: ["Swift"],
            preferredDomains: [.iosDeveloper],
            experienceLevel: .fresher
        )
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Empty User Skills

    func testEmptyUserSkillsReturnsZeroSkillContribution() {
        let job = makeJob(
            tags: ["Swift", "UIKit"],
            domain: .iosDeveloper,
            experienceLevel: .fresher
        )
        let results = engine.recommend(
            jobs: [job],
            userSkills: [],
            preferredDomains: [.iosDeveloper],
            experienceLevel: .fresher
        )
        XCTAssertEqual(results.count, 1)
        // skill=0, domain=100, experience=100
        // 0*0.40 + 100*0.35 + 100*0.25 = 0 + 35 + 25 = 60
        XCTAssertEqual(results[0].relevanceScore, 60)
    }

    // MARK: - Results Sorted by Descending Relevance

    func testResultsSortedByDescendingRelevance() {
        // Perfect match: 1 tag = 1 user skill = 100% skill → 100 total
        let perfectJob = makeJob(
            id: "perfect",
            tags: ["Swift"],
            domain: .iosDeveloper,
            experienceLevel: .fresher
        )
        // Partial match: 2 tags, 1 user match = 50% skill → 50*0.4+100*0.35+100*0.25 = 80
        let partialJob = makeJob(
            id: "partial",
            tags: ["Swift", "Python"],
            domain: .iosDeveloper,
            experienceLevel: .fresher
        )
        // No match: 0% skill, 0% domain, 0% experience → 0 total
        let noMatchJob = makeJob(
            id: "nomatch",
            tags: ["Python"],
            domain: .backendEngineer,
            experienceLevel: .experienced
        )

        let results = engine.recommend(
            jobs: [noMatchJob, partialJob, perfectJob],
            userSkills: ["Swift"],
            preferredDomains: [.iosDeveloper],
            experienceLevel: .fresher
        )
        XCTAssertGreaterThan(results[0].relevanceScore, results[1].relevanceScore)
        XCTAssertGreaterThan(results[1].relevanceScore, results[2].relevanceScore)
        XCTAssertEqual(results[0].id, "perfect")
        XCTAssertEqual(results[1].id, "partial")
        XCTAssertEqual(results[2].id, "nomatch")
    }

    // MARK: - Relevance Labels

    func testRelevanceLabelForHighlyRelevant() {
        let rec = RecommendedJob(
            job: makeJob(id: "1"),
            relevanceScore: 92,
            relevanceLabel: "95% Relevant"
        )
        XCTAssertEqual(rec.relevanceLabel, "95% Relevant")
    }

    func testRelevanceLabelForModerateRelevance() {
        let rec = RecommendedJob(
            job: makeJob(id: "1"),
            relevanceScore: 75,
            relevanceLabel: "80% Relevant"
        )
        XCTAssertEqual(rec.relevanceLabel, "80% Relevant")
    }

    func testRelevanceLabelForLowRelevance() {
        let rec = RecommendedJob(
            job: makeJob(id: "1"),
            relevanceScore: 55,
            relevanceLabel: "60% Relevant"
        )
        XCTAssertEqual(rec.relevanceLabel, "60% Relevant")
    }

    func testRecommendationOutputLabelIsCorrectForHighScore() {
        let job = makeJob(
            tags: ["Swift", "SwiftUI", "CoreData"],
            domain: .iosDeveloper,
            experienceLevel: .fresher
        )
        let results = engine.recommend(
            jobs: [job],
            userSkills: ["Swift", "SwiftUI", "CoreData"],
            preferredDomains: [.iosDeveloper],
            experienceLevel: .fresher
        )
        XCTAssertEqual(results[0].relevanceLabel, "95% Relevant")
    }

    func testRecommendationOutputLabelIsCorrectForModerateScore() {
        let job = makeJob(
            tags: ["Swift"],
            domain: .iosDeveloper,
            experienceLevel: .fresher
        )
        let results = engine.recommend(
            jobs: [job],
            userSkills: ["Swift"],
            preferredDomains: [],
            experienceLevel: nil
        )
        XCTAssertEqual(results[0].relevanceLabel, "80% Relevant")
    }

    func testRecommendationOutputLabelIsCorrectForLowScore() {
        let job = makeJob(
            tags: ["Python", "Django"],
            domain: .backendEngineer,
            experienceLevel: .experienced
        )
        let results = engine.recommend(
            jobs: [job],
            userSkills: ["Swift"],
            preferredDomains: [],
            experienceLevel: nil
        )
        XCTAssertEqual(results[0].relevanceLabel, "60% Relevant")
    }

    // MARK: - isHighlyRelevant

    func testIsHighlyRelevantTrueFor90Plus() {
        let rec = RecommendedJob(
            job: makeJob(id: "1"),
            relevanceScore: 90,
            relevanceLabel: "95% Relevant"
        )
        XCTAssertTrue(rec.isHighlyRelevant)
    }

    func testIsHighlyRelevantTrueFor100() {
        let rec = RecommendedJob(
            job: makeJob(id: "1"),
            relevanceScore: 100,
            relevanceLabel: "95% Relevant"
        )
        XCTAssertTrue(rec.isHighlyRelevant)
    }

    func testIsHighlyRelevantFalseFor89() {
        let rec = RecommendedJob(
            job: makeJob(id: "1"),
            relevanceScore: 89,
            relevanceLabel: "80% Relevant"
        )
        XCTAssertFalse(rec.isHighlyRelevant)
    }

    func testIsHighlyRelevantFalseFor70() {
        let rec = RecommendedJob(
            job: makeJob(id: "1"),
            relevanceScore: 70,
            relevanceLabel: "80% Relevant"
        )
        XCTAssertFalse(rec.isHighlyRelevant)
    }

    // MARK: - colorName

    func testColorNameGreenForHighScore() {
        let rec = RecommendedJob(
            job: makeJob(id: "1"),
            relevanceScore: 95,
            relevanceLabel: "95% Relevant"
        )
        XCTAssertEqual(rec.colorName, "green")
    }

    func testColorNameBlueForModerateScore() {
        let rec = RecommendedJob(
            job: makeJob(id: "1"),
            relevanceScore: 75,
            relevanceLabel: "80% Relevant"
        )
        XCTAssertEqual(rec.colorName, "blue")
    }

    func testColorNameOrangeForLowScore() {
        let rec = RecommendedJob(
            job: makeJob(id: "1"),
            relevanceScore: 50,
            relevanceLabel: "60% Relevant"
        )
        XCTAssertEqual(rec.colorName, "orange")
    }

    // MARK: - id Matches Job id

    func testRecommendedJobIdMatchesJobId() {
        let job = makeJob(id: "abc-123")
        let rec = RecommendedJob(
            job: job,
            relevanceScore: 80,
            relevanceLabel: "80% Relevant"
        )
        XCTAssertEqual(rec.id, "abc-123")
    }

    // MARK: - Score Clamping

    func testScoreIsClampedToMax100() {
        let rec = RecommendedJob(
            job: makeJob(id: "1"),
            relevanceScore: 150,
            relevanceLabel: ""
        )
        XCTAssertEqual(rec.relevanceScore, 100)
    }

    func testScoreIsClampedToMin0() {
        let rec = RecommendedJob(
            job: makeJob(id: "1"),
            relevanceScore: -10,
            relevanceLabel: ""
        )
        XCTAssertEqual(rec.relevanceScore, 0)
    }

    // MARK: - Multiple Jobs Same Score

    func testMultipleJobsAllReturned() {
        let jobs = [
            makeJob(id: "1", tags: ["Swift"], domain: .iosDeveloper, experienceLevel: .fresher),
            makeJob(id: "2", tags: ["Swift"], domain: .iosDeveloper, experienceLevel: .fresher),
            makeJob(id: "3", tags: ["Swift"], domain: .iosDeveloper, experienceLevel: .fresher)
        ]
        let results = engine.recommend(
            jobs: jobs,
            userSkills: ["Swift"],
            preferredDomains: [.iosDeveloper],
            experienceLevel: .fresher
        )
        XCTAssertEqual(results.count, 3)
    }
}
