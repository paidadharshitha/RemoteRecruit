// SavedJobsViewModelTests.swift
// RemoteRecruitTests

import XCTest
@testable import RemoteRecruit

// MARK: - Tests

@MainActor
final class SavedJobsViewModelTests: XCTestCase {

    private var mockJobService: MockJobService!

    // MARK: - Helpers

    private func makeJob(id: String = "1", title: String = "Engineer") -> Job {
        Job(id: id, title: title, companyName: "Acme", location: "Remote",
             salaryRange: "$100k", jobDescription: "Build things.", tags: ["Swift"],
             postedDate: Date(), domain: .iosDeveloper, experienceLevel: .fresher)
    }

    // MARK: - setUp / tearDown

    override func setUp() {
        mockJobService = MockJobService(jobsToReturn: [])
    }

    override func tearDown() {
        mockJobService.reset()
        mockJobService = nil
    }

    private func makeViewModel(savedIds: Set<String> = []) -> SavedJobsViewModel {
        let savedJobsManager = SavedJobsManager(savedIds: savedIds)
        return SavedJobsViewModel(savedJobsManager: savedJobsManager, jobService: mockJobService)
    }

    // MARK: - Initial State

    func testInitialStateIsIdle() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.viewState, .idle)
    }

    // MARK: - Load Saved Jobs

    func testLoadSavedJobsWithSavedIdsReturnsFilteredJobs() async {
        let job1 = makeJob(id: "1", title: "iOS Engineer")
        let job2 = makeJob(id: "2", title: "Backend Engineer")
        let job3 = makeJob(id: "3", title: "Designer")
        mockJobService.jobsToReturn = [job1, job2, job3]

        let vm = makeViewModel(savedIds: ["1", "3"])

        await vm.loadSavedJobs()

        guard case .success(let data) = vm.viewState else {
            XCTFail("Expected success state")
            return
        }
        XCTAssertEqual(data.count, 2)
        XCTAssertEqual(data.map(\.id).sorted(), ["1", "3"])
    }

    func testLoadSavedJobsWithNoSavedIdsReturnsEmpty() async {
        let vm = makeViewModel(savedIds: [])

        await vm.loadSavedJobs()

        XCTAssertEqual(vm.viewState, .empty)
    }

    func testLoadSavedJobsWithNetworkErrorReturnsError() async {
        mockJobService.errorToThrow = JobServiceError.networkUnavailable
        let vm = makeViewModel(savedIds: ["1"])

        await vm.loadSavedJobs()

        XCTAssertEqual(vm.viewState, .error(message: JobServiceError.networkUnavailable.errorDescription ?? "Unknown error"))
    }

    func testLoadSavedJobsWhenAllJobsFilteredOutReturnsEmpty() async {
        mockJobService.jobsToReturn = [makeJob(id: "10", title: "Other")]
        let vm = makeViewModel(savedIds: ["1", "2"])

        await vm.loadSavedJobs()

        XCTAssertEqual(vm.viewState, .empty)
    }

    // MARK: - Toggle Save

    func testToggleSaveUnsavesASavedJob() async {
        let job = makeJob(id: "1")
        mockJobService.jobsToReturn = [job]
        let vm = makeViewModel(savedIds: ["1"])

        XCTAssertTrue(vm.isSaved(jobId: "1"))

        vm.toggleSave(job)

        // Wait for the async reload triggered by toggleSave
        await Task.yield()

        XCTAssertFalse(vm.isSaved(jobId: "1"))
        XCTAssertEqual(vm.savedCount, 0)
    }

    func testToggleSaveSavesAnUnsavedJob() async {
        let job = makeJob(id: "1")
        mockJobService.jobsToReturn = [job]
        let vm = makeViewModel(savedIds: [])

        XCTAssertFalse(vm.isSaved(jobId: "1"))

        vm.toggleSave(job)

        await Task.yield()

        XCTAssertTrue(vm.isSaved(jobId: "1"))
        XCTAssertEqual(vm.savedCount, 1)
    }

    // MARK: - isSaved

    func testIsSavedReturnsCorrectState() {
        let vm = makeViewModel(savedIds: ["1", "3"])
        XCTAssertTrue(vm.isSaved(jobId: "1"))
        XCTAssertTrue(vm.isSaved(jobId: "3"))
        XCTAssertFalse(vm.isSaved(jobId: "2"))
        XCTAssertFalse(vm.isSaved(jobId: ""))
    }

    // MARK: - savedCount

    func testSavedCountReflectsCurrentCount() {
        let vm = makeViewModel(savedIds: ["1", "2", "3"])
        XCTAssertEqual(vm.savedCount, 3)
    }

    func testSavedCountWithEmptySet() {
        let vm = makeViewModel(savedIds: [])
        XCTAssertEqual(vm.savedCount, 0)
    }

    // MARK: - Refresh

    func testRefreshReloadsJobs() async {
        let job = makeJob(id: "1")
        mockJobService.jobsToReturn = [job]
        let vm = makeViewModel(savedIds: ["1"])

        await vm.refresh()

        XCTAssertEqual(mockJobService.fetchJobsCallCount, 1)
        guard case .success(let data) = vm.viewState else {
            XCTFail("Expected success state")
            return
        }
        XCTAssertEqual(data.count, 1)

        await vm.refresh()

        XCTAssertEqual(mockJobService.fetchJobsCallCount, 2)
    }
}
