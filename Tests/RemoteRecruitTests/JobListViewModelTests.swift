// JobListViewModelTests.swift
// RemoteRecruitTests

import XCTest
@testable import RemoteRecruit

// MARK: - Mock Job Service

/// Testable stub — returns preset data or simulated errors synchronously.
final class MockJobService: JobServiceProtocol, @unchecked Sendable {

    var jobsToReturn: [Job] = MockData.sampleJobs
    var errorToThrow: Error?
    private var fetchJobsCallCount = 0
    private var fetchJobCallCount = 0

    var fetchJobsCallCounts: Int { fetchJobsCallCount }
    var fetchJobCallCounts: Int { fetchJobCallCount }

    func fetchJobs() async throws -> [Job] {
        fetchJobsCallCount += 1
        if let error = errorToThrow {
            throw error
        }
        return jobsToReturn
    }

    func fetchJob(by id: UUID) async throws -> Job {
        fetchJobCallCount += 1
        if let error = errorToThrow {
            throw error
        }
        guard let job = jobsToReturn.first(where: { $0.id == id }) else {
            throw JobServiceError.custom(message: "Job not found.")
        }
        return job
    }

    func reset() {
        jobsToReturn = MockData.sampleJobs
        errorToThrow = nil
        fetchJobsCallCount = 0
        fetchJobCallCount = 0
    }
}

// MARK: - JobServiceError Tests

final class JobServiceErrorTests: XCTestCase {

    func testNetworkUnavailableDescription() {
        let error = JobServiceError.networkUnavailable
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Network"))
    }

    func testServerErrorDescription() {
        let error = JobServiceError.serverError(statusCode: 500)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("500"))
    }

    func testDecodingErrorDescription() {
        let error = JobServiceError.decodingError
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("parse"))
    }

    func testUnauthorizedDescription() {
        let error = JobServiceError.unauthorized
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("sign in"))
    }

    func testCustomErrorMessage() {
        let error = JobServiceError.custom(message: "Something specific failed")
        XCTAssertEqual(error.errorDescription, "Something specific failed")
    }

    func testEquality() {
        XCTAssertEqual(JobServiceError.networkUnavailable, JobServiceError.networkUnavailable)
        XCTAssertEqual(JobServiceError.serverError(statusCode: 404), JobServiceError.serverError(statusCode: 404))
        XCTAssertNotEqual(JobServiceError.decodingError, JobServiceError.unauthorized)
        XCTAssertEqual(JobServiceError.custom(message: "a"), JobServiceError.custom(message: "a"))
        XCTAssertNotEqual(JobServiceError.custom(message: "a"), JobServiceError.custom(message: "b"))
    }
}

// MARK: - ViewState Tests

final class ViewStateTests: XCTestCase {

    func testIdleState() {
        let state: ViewState<String> = .idle
        XCTAssertNil(state.data)
        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.errorMessage)
    }

    func testLoadingState() {
        let state: ViewState<[Int]> = .loading
        XCTAssertNil(state.data)
        XCTAssertTrue(state.isLoading)
        XCTAssertNil(state.errorMessage)
    }

    func testSuccessState() {
        let state: ViewState<[String]> = .success(data: ["a", "b"])
        XCTAssertEqual(state.data, ["a", "b"])
        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.errorMessage)
    }

    func testEmptyState() {
        let state: ViewState<[Job]> = .empty
        XCTAssertNil(state.data)
        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.errorMessage)
    }

    func testErrorState() {
        let state: ViewState<[Job]> = .error(message: "timeout")
        XCTAssertNil(state.data)
        XCTAssertFalse(state.isLoading)
        XCTAssertEqual(state.errorMessage, "timeout")
    }
}

// MARK: - Job Model Tests

final class JobModelTests: XCTestCase {

    func testJobInitialization() {
        let job = Job(
            title: "Engineer",
            companyName: "Acme",
            location: "Remote",
            salaryRange: "$100k",
            jobDescription: "Build things."
        )
        XCTAssertEqual(job.title, "Engineer")
        XCTAssertEqual(job.companyName, "Acme")
        XCTAssertEqual(job.location, "Remote")
        XCTAssertEqual(job.salaryRange, "$100k")
        XCTAssertEqual(job.jobDescription, "Build things.")
        XCTAssertTrue(job.tags.isEmpty)
    }

    func testJobWithTags() {
        let job = Job(
            title: "Dev",
            companyName: "Co",
            location: "NYC",
            salaryRange: "$50k",
            jobDescription: "Code.",
            tags: ["Swift", "iOS"]
        )
        XCTAssertEqual(job.tags, ["Swift", "iOS"])
    }

    func testJobIdentifiable() {
        let id = UUID()
        let job = Job(id: id, title: "T", companyName: "C", location: "L", salaryRange: "S", jobDescription: "D")
        XCTAssertEqual(job.id, id)
    }

    func testJobHashable() {
        let job1 = Job(id: UUID(), title: "T", companyName: "C", location: "L", salaryRange: "S", jobDescription: "D")
        let job2 = Job(id: job1.id, title: "T", companyName: "C", location: "L", salaryRange: "S", jobDescription: "D")
        XCTAssertEqual(job1, job2)
    }

    func testMockDataHasJobs() {
        XCTAssertFalse(MockData.sampleJobs.isEmpty)
        for job in MockData.sampleJobs {
            XCTAssertFalse(job.title.isEmpty)
            XCTAssertFalse(job.companyName.isEmpty)
            XCTAssertFalse(job.salaryRange.isEmpty)
            XCTAssertFalse(job.jobDescription.isEmpty)
        }
    }
}

// MARK: - JobListViewModel Tests

@MainActor
final class JobListViewModelTests: XCTestCase {

    private var mockService: MockJobService!
    private var sut: JobListViewModel!

    override func setUp() {
        super.setUp()
        mockService = MockJobService()
        sut = JobListViewModel(service: mockService)
        // Reset singleton state to defaults before each test
        AppState.shared.selectedDomain = .iosDeveloper
        AppState.shared.selectedExperienceLevel = .student
        AppState.shared.searchText = ""
    }

    override func tearDown() {
        mockService.reset()
        mockService = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateIsIdle() {
        XCTAssertEqual(sut.viewState, .idle)
        XCTAssertTrue(AppState.shared.searchText.isEmpty)
    }

    // MARK: - Success State

    func testLoadJobsSuccess() async {
        await sut.loadJobs()

        if case .success(let data) = sut.viewState {
            // Default filter: iOS Developer + Student — should return intern iOS jobs (capped at 6)
            XCTAssertTrue(data.count > 0)
            XCTAssertTrue(data.count <= 6)
            XCTAssertTrue(data.allSatisfy { $0.domain == .iosDeveloper && $0.experienceLevel == .student })
        } else {
            XCTFail("Expected success state, got \(sut.viewState)")
        }
    }

    func testLoadJobsCallsServiceOnce() async {
        await sut.loadJobs()
        XCTAssertEqual(mockService.fetchJobsCallCounts, 1)
    }

    func testLoadJobsReturnsCorrectJobTitles() async {
        await sut.loadJobs()

        guard let jobs = sut.viewState.data else {
            XCTFail("Expected data in success state")
            return
        }

        // Default filter: iOS Developer + Student — should see intern titles
        let titles = jobs.map(\.title)
        XCTAssertTrue(titles.contains(where: { $0.contains("Intern") || $0.contains("Co-op") })
    }

    // MARK: - Loading Guard

    func testLoadJobsWhileLoadingIsIgnored() async {
        let secondCallExpectation = XCTestExpectation(description: "Second call completes")

        mockService.jobsToReturn = []
        mockService.errorToThrow = nil
        AppState.shared.searchText = ""

        // Fire the first (non-awaited) load to set .loading, then await a second call
        Task { await sut.loadJobs() }
        await sut.loadJobs()

        // loadJobs guard should have prevented the second service call
        XCTAssertEqual(mockService.fetchJobsCallCounts, 1)

        secondCallExpectation.fulfill()
        await fulfillment(of: [secondCallExpectation], timeout: 1.0)
    }

    // MARK: - Empty State

    func testLoadJobsEmptyResults() async {
        mockService.jobsToReturn = []
        await sut.loadJobs()

        XCTAssertEqual(sut.viewState, .empty)
    }

    // MARK: - Error State

    func testLoadJobsNetworkError() async {
        mockService.errorToThrow = JobServiceError.networkUnavailable
        await sut.loadJobs()

        if case .error(let message) = sut.viewState {
            XCTAssertTrue(message.contains("Network"))
        } else {
            XCTFail("Expected error state, got \(sut.viewState)")
        }
    }

    func testLoadJobsServerError() async {
        mockService.errorToThrow = JobServiceError.serverError(statusCode: 500)
        await sut.loadJobs()

        if case .error(let message) = sut.viewState {
            XCTAssertTrue(message.contains("500"))
        } else {
            XCTFail("Expected error state, got \(sut.viewState)")
        }
    }

    func testLoadJobsDecodingError() async {
        mockService.errorToThrow = JobServiceError.decodingError
        await sut.loadJobs()

        if case .error(let message) = sut.viewState {
            XCTAssertTrue(message.contains("parse"))
        } else {
            XCTFail("Expected error state, got \(sut.viewState)")
        }
    }

    func testLoadJobsUnauthorizedError() async {
        mockService.errorToThrow = JobServiceError.unauthorized
        await sut.loadJobs()

        if case .error(let message) = sut.viewState {
            XCTAssertTrue(message.contains("Session"))
        } else {
            XCTFail("Expected error state, got \(sut.viewState)")
        }
    }

    func testLoadJobsCustomError() async {
        mockService.errorToThrow = JobServiceError.custom(message: "Rate limited")
        await sut.loadJobs()

        if case .error(let message) = sut.viewState {
            XCTAssertEqual(message, "Rate limited")
        } else {
            XCTFail("Expected error state, got \(sut.viewState)")
        }
    }

    // MARK: - Refresh

    func testRefreshClearsAndReloads() async {
        await sut.loadJobs()
        XCTAssertEqual(mockService.fetchJobsCallCounts, 1)

        await sut.refresh()
        XCTAssertEqual(mockService.fetchJobsCallCounts, 2)
    }

    // MARK: - Search: By Title

    func testSearchByTitleFiltersCorrectly() async {
        // Use Experienced level to get more iOS jobs
        AppState.shared.selectedExperienceLevel = .experienced
        await sut.loadJobs()

        AppState.shared.searchText = "Senior"
        sut.applyFilter()
        guard let results = sut.viewState.data else {
            XCTFail("Expected success with filtered data")
            return
        }

        XCTAssertTrue(results.allSatisfy { $0.title.localizedCaseInsensitiveContains("Senior") })
        XCTAssertTrue(results.count > 0)
    }

    // MARK: - Search: By Company

    func testSearchByCompanyFiltersCorrectly() async {
        await sut.loadJobs()

        AppState.shared.searchText = "apple"
        sut.applyFilter()
        guard let results = sut.viewState.data else {
            XCTFail("Expected success with filtered data")
            return
        }

        XCTAssertTrue(results.allSatisfy { $0.companyName.localizedCaseInsensitiveContains("apple") })
        XCTAssertTrue(results.count > 0)
    }

    // MARK: - Search: Case Insensitive

    func testSearchIsCaseInsensitive() async {
        await sut.loadJobs()

        AppState.shared.searchText = "APPLE"
        sut.applyFilter()
        guard let results = sut.viewState.data else {
            XCTFail("Expected success with filtered data")
            return
        }

        XCTAssertTrue(results.count > 0)
    }

    func testSearchMixedCase() async {
        // Switch to Backend domain + Fresher to get Notion
        AppState.shared.selectedDomain = .backendEngineer
        AppState.shared.selectedExperienceLevel = .fresher
        await sut.loadJobs()

        AppState.shared.searchText = "NoTiOn"
        sut.applyFilter()
        guard let results = sut.viewState.data else {
            XCTFail("Expected success with filtered data")
            return
        }

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.companyName, "Notion")
    }

    // MARK: - Search: No Results

    func testSearchWithNoMatchesShowsEmpty() async {
        await sut.loadJobs()

        AppState.shared.searchText = "zzznonexistent"
        sut.applyFilter()
        XCTAssertEqual(sut.viewState, .empty)
    }

    // MARK: - Search: Clear restores all

    func testClearingSearchRestoresAllJobs() async {
        await sut.loadJobs()

        AppState.shared.searchText = "nonexistent"
        sut.applyFilter()
        XCTAssertEqual(sut.viewState.data?.count, 0)

        AppState.shared.searchText = ""
        sut.applyFilter()
        XCTAssertTrue(sut.viewState.data?.count ?? 0 > 0)
    }

    // MARK: - Search: Whitespace only

    func testSearchWithWhitespaceOnlyReturnsAll() async {
        await sut.loadJobs()

        AppState.shared.searchText = "   "
        sut.applyFilter()
        XCTAssertTrue(sut.viewState.data?.count ?? 0 > 0)
    }

    // MARK: - Search: Partial match

    func testSearchPartialMatch() async {
        await sut.loadJobs()

        AppState.shared.searchText = "Intern"
        sut.applyFilter()
        guard let results = sut.viewState.data else {
            XCTFail("Expected success with filtered data")
            return
        }

        XCTAssertGreaterThan(results.count, 0)
        XCTAssertTrue(results.allSatisfy {
            $0.title.localizedCaseInsensitiveContains("Intern")
        })
    }

    // MARK: - Search: Matches title OR company

    func testSearchMatchesTitleOrCompany() async {
        // Switch to Product Designer + Student to get Figma
        AppState.shared.selectedDomain = .productDesigner
        AppState.shared.selectedExperienceLevel = .student
        await sut.loadJobs()

        // "figma" matches company "Figma" not any title
        AppState.shared.searchText = "figma"
        sut.applyFilter()
        guard let results = sut.viewState.data else {
            XCTFail("Expected success with filtered data")
            return
        }

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.companyName, "Figma")
    }

    // MARK: - applyFilter edge cases

    func testApplyFilterOnEmptySourceShowsEmpty() async {
        // Load empty jobs
        mockService.jobsToReturn = []
        await sut.loadJobs()
        XCTAssertEqual(sut.viewState, .empty)

        // Even with a search term, should remain empty
        AppState.shared.searchText = "anything"
        sut.applyFilter()
        XCTAssertEqual(sut.viewState, .empty)
    }

    // MARK: - Domain Filter

    func testDomainFilterReturnsCorrectJobs() async {
        AppState.shared.selectedExperienceLevel = .experienced
        AppState.shared.selectedDomain = .backendEngineer
        await sut.loadJobs()

        guard let jobs = sut.viewState.data else {
            XCTFail("Expected success data")
            return
        }
        XCTAssertTrue(jobs.allSatisfy { $0.domain == .backendEngineer })
        XCTAssertTrue(jobs.allSatisfy { $0.experienceLevel == .experienced })
    }

    // MARK: - Experience Level Filter

    func testExperienceLevelFilterReturnsCorrectJobs() async {
        AppState.shared.selectedExperienceLevel = .fresher
        AppState.shared.selectedDomain = .dataScientist
        await sut.loadJobs()

        guard let jobs = sut.viewState.data else {
            XCTFail("Expected success data")
            return
        }
        XCTAssertTrue(jobs.allSatisfy { $0.experienceLevel == .fresher })
        XCTAssertTrue(jobs.allSatisfy { $0.domain == .dataScientist })
    }
}

// MARK: - MockJobService Tests

final class MockJobServiceTests: XCTestCase {

    func testFetchJobsReturnsSampleJobs() async {
        let service = MockJobService()
        let jobs = try? await service.fetchJobs()
        XCTAssertEqual(jobs?.count, MockData.sampleJobs.count)
    }

    func testFetchJobsThrowsError() async {
        let service = MockJobService()
        service.errorToThrow = JobServiceError.networkUnavailable

        do {
            _ = try await service.fetchJobs()
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual(error as? JobServiceError, .networkUnavailable)
        }
    }

    func testFetchJobById() async {
        let service = MockJobService()
        let targetID = MockData.sampleJobs[0].id

        let job = try? await service.fetchJob(by: targetID)
        XCTAssertEqual(job?.id, targetID)
    }

    func testFetchJobNotFound() async {
        let service = MockJobService()

        do {
            _ = try await service.fetchJob(by: UUID())
            XCTFail("Should have thrown")
        } catch let error as JobServiceError {
            if case .custom(let msg) = error {
                XCTAssertTrue(msg.contains("not found"))
            } else {
                XCTFail("Expected custom error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    func testFetchJobThrowsError() async {
        let service = MockJobService()
        service.errorToThrow = JobServiceError.unauthorized

        do {
            _ = try await service.fetchJob(by: UUID())
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual(error as? JobServiceError, .unauthorized)
        }
    }

    func testResetClearsState() async {
        let service = MockJobService()
        service.errorToThrow = JobServiceError.decodingError
        _ = try? await service.fetchJobs()
        XCTAssertEqual(service.fetchJobsCallCounts, 1)

        service.reset()
        XCTAssertEqual(service.fetchJobsCallCounts, 0)
        XCTAssertNil(service.errorToThrow)
    }
}
