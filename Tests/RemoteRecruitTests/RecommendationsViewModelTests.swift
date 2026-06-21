// RecommendationsViewModelTests.swift
// RemoteRecruitTests

import XCTest
@testable import RemoteRecruit

// MARK: - Mock Recommendation Engine

private final class MockRecommendationEngine: Recommending {
    var recommendationsToReturn: [RecommendedJob] = []
    private(set) var recommendCallCount: Int = 0

    func recommend(
        jobs: [Job],
        userSkills: [String],
        preferredDomains: [JobDomain],
        experienceLevel: ExperienceLevel?
    ) -> [RecommendedJob] {
        recommendCallCount += 1
        return recommendationsToReturn
    }
}

// MARK: - Tests

@MainActor
final class RecommendationsViewModelTests: XCTestCase {

    private var mockEngine: MockRecommendationEngine!
    private var mockJobService: MockJobService!
    private var savedProfile: UserProfile?

    // MARK: - Helpers

    private func makeJob(id: String = "1", tags: [String] = ["Swift", "SwiftUI"]) -> Job {
        Job(id: id, title: "iOS Engineer", companyName: "Acme", location: "Remote",
             salaryRange: "$100k", jobDescription: "Build iOS apps.", tags: tags,
             postedDate: Date(), domain: .iosDeveloper, experienceLevel: .fresher)
    }

    private func makeRecommendedJob(id: String, score: Int) -> RecommendedJob {
        RecommendedJob(job: makeJob(id: id), relevanceScore: score, relevanceLabel: "\(score)% Relevant")
    }

    // MARK: - setUp / tearDown

    override func setUp() {
        mockEngine = MockRecommendationEngine()
        mockJobService = MockJobService(jobsToReturn: [])
        // Save and clear profile to avoid cross-test contamination
        savedProfile = AppState.shared.profile
        AppState.shared.setProfile(nil)
        AppState.shared.profileSkills = []
    }

    override func tearDown() {
        AppState.shared.setProfile(savedProfile)
        mockEngine = nil
        mockJobService = nil
    }

    private func makeViewModel() -> RecommendationsViewModel {
        RecommendationsViewModel(engine: mockEngine, jobService: mockJobService)
    }

    // MARK: - Initial State

    func testInitialStateIsIdle() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.viewState, .idle)
    }

    // MARK: - Load Recommendations

    func testLoadRecommendationsTransitionsToSuccess() async {
        mockJobService.jobsToReturn = [makeJob(id: "1"), makeJob(id: "2")]
        mockEngine.recommendationsToReturn = [
            makeRecommendedJob(id: "1", score: 90),
            makeRecommendedJob(id: "2", score: 70)
        ]
        let vm = makeViewModel()

        await vm.loadRecommendations()

        // Verify intermediate loading was reached (final state should be success)
        XCTAssertEqual(vm.viewState, .success(data: mockEngine.recommendationsToReturn))
        XCTAssertEqual(mockEngine.recommendCallCount, 1)
        XCTAssertEqual(mockJobService.fetchJobsCallCount, 1)
    }

    func testLoadRecommendationsWithEmptyJobsReturnsEmpty() async {
        mockJobService.jobsToReturn = []
        mockEngine.recommendationsToReturn = []
        let vm = makeViewModel()

        await vm.loadRecommendations()

        XCTAssertEqual(vm.viewState, .empty)
    }

    func testLoadRecommendationsWithNetworkErrorReturnsError() async {
        mockJobService.errorToThrow = JobServiceError.networkUnavailable
        let vm = makeViewModel()

        await vm.loadRecommendations()

        XCTAssertEqual(vm.viewState, .error(message: JobServiceError.networkUnavailable.errorDescription ?? "Unknown error"))
    }

    func testSuccessStateContainsSortedRecommendedJobs() async {
        mockJobService.jobsToReturn = [makeJob(id: "1"), makeJob(id: "2"), makeJob(id: "3")]
        // Engine returns sorted by relevance (highest first)
        mockEngine.recommendationsToReturn = [
            makeRecommendedJob(id: "1", score: 95),
            makeRecommendedJob(id: "2", score: 80),
            makeRecommendedJob(id: "3", score: 60)
        ]
        let vm = makeViewModel()

        await vm.loadRecommendations()

        guard case .success(let data) = vm.viewState else {
            XCTFail("Expected success state")
            return
        }
        XCTAssertEqual(data.count, 3)
        // Verify sorted descending by relevance
        XCTAssertTrue(data[0].relevanceScore >= data[1].relevanceScore)
        XCTAssertTrue(data[1].relevanceScore >= data[2].relevanceScore)
    }

    // MARK: - Refresh

    func testRefreshCallsServiceAgain() async {
        mockJobService.jobsToReturn = [makeJob()]
        mockEngine.recommendationsToReturn = [makeRecommendedJob(id: "1", score: 90)]
        let vm = makeViewModel()

        await vm.refresh()

        XCTAssertEqual(mockJobService.fetchJobsCallCount, 1)

        await vm.refresh()

        XCTAssertEqual(mockJobService.fetchJobsCallCount, 2)
        XCTAssertEqual(mockEngine.recommendCallCount, 2)
    }

    // MARK: - Error Recovery

    func testLoadRecommendationsRecoversFromError() async {
        mockJobService.errorToThrow = JobServiceError.serverError(statusCode: 500)
        let vm = makeViewModel()

        await vm.loadRecommendations()
        XCTAssertEqual(vm.viewState, .error(message: JobServiceError.serverError(statusCode: 500).errorDescription ?? "Unknown error"))

        // Recover
        mockJobService.errorToThrow = nil
        mockJobService.jobsToReturn = [makeJob()]
        mockEngine.recommendationsToReturn = [makeRecommendedJob(id: "1", score: 85)]

        await vm.loadRecommendations()
        XCTAssertEqual(vm.viewState, .success(data: [makeRecommendedJob(id: "1", score: 85)]))
    }
}
