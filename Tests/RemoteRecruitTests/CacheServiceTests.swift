// CacheServiceTests.swift
// RemoteRecruitTests

import XCTest
@testable import RemoteRecruit

// MARK: - CacheService Tests

final class CacheServiceTests: XCTestCase {

    // MARK: - Properties

    private var cacheDirectory: URL!
    private var sut: CacheService!

    // MARK: - Helpers

    private func makeJob(id: String = "1", title: String = "Engineer") -> Job {
        Job(
            id: id,
            title: title,
            companyName: "Acme",
            location: "Remote",
            salaryRange: "$100k",
            jobDescription: "Build things.",
            tags: ["Swift"],
            postedDate: Date(),
            domain: .iosDeveloper,
            experienceLevel: .fresher
        )
    }

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
        cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        sut = CacheService(cacheDirectory: cacheDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        sut = nil
        cacheDirectory = nil
        super.tearDown()
    }

    // MARK: - Cache and Load

    func testCacheAndLoadReturnsSameJobs() async throws {
        let jobs = [makeJob(id: "1"), makeJob(id: "2", title: "Designer")]
        try await sut.cacheJobs(jobs)

        let envelope = try await sut.loadCachedJobs()
        XCTAssertNotNil(envelope)
        XCTAssertEqual(envelope!.jobs.count, 2)
        XCTAssertEqual(envelope!.jobs[0].id, "1")
        XCTAssertEqual(envelope!.jobs[1].id, "2")
        XCTAssertEqual(envelope!.jobs[0].title, "Engineer")
        XCTAssertEqual(envelope!.jobs[1].title, "Designer")
    }

    // MARK: - Load from Empty Cache

    func testLoadFromEmptyCacheReturnsNil() async throws {
        let envelope = try await sut.loadCachedJobs()
        XCTAssertNil(envelope)
    }

    // MARK: - hasCachedJobs Initially False

    func testHasCachedJobsInitiallyFalse() {
        XCTAssertFalse(sut.hasCachedJobs())
    }

    // MARK: - hasCachedJobs True After Caching

    func testHasCachedJobsTrueAfterCaching() async throws {
        try await sut.cacheJobs([makeJob()])
        XCTAssertTrue(sut.hasCachedJobs())
    }

    // MARK: - Cache Overwrites Previous Data

    func testCacheOverwritesPreviousData() async throws {
        let firstJobs = [makeJob(id: "1")]
        try await sut.cacheJobs(firstJobs)

        let secondJobs = [makeJob(id: "2", title: "Architect"), makeJob(id: "3", title: "PM")]
        try await sut.cacheJobs(secondJobs)

        let envelope = try await sut.loadCachedJobs()
        XCTAssertNotNil(envelope)
        XCTAssertEqual(envelope!.jobs.count, 2)
        XCTAssertEqual(envelope!.jobs[0].id, "2")
        XCTAssertEqual(envelope!.jobs[1].id, "3")
    }

    // MARK: - Clear Cache Removes Data

    func testClearCacheRemovesData() async throws {
        try await sut.cacheJobs([makeJob()])
        XCTAssertTrue(sut.hasCachedJobs())

        try await sut.clearCache()
        XCTAssertFalse(sut.hasCachedJobs())

        let envelope = try await sut.loadCachedJobs()
        XCTAssertNil(envelope)
    }

    // MARK: - isExpired False for Fresh Cache

    func testIsExpiredFalseForFreshCache() async throws {
        try await sut.cacheJobs([makeJob()])
        let envelope = try await sut.loadCachedJobs()
        XCTAssertNotNil(envelope)
        XCTAssertFalse(envelope!.isExpired)
    }

    // MARK: - Empty Jobs List

    func testCacheWithEmptyJobsList() async throws {
        try await sut.cacheJobs([])

        XCTAssertTrue(sut.hasCachedJobs())

        let envelope = try await sut.loadCachedJobs()
        XCTAssertNotNil(envelope)
        XCTAssertTrue(envelope!.jobs.isEmpty)
    }

    // MARK: - Multiple Sequential Cycles

    func testMultipleSequentialCacheLoadCycles() async throws {
        // Cycle 1
        let jobs1 = [makeJob(id: "1")]
        try await sut.cacheJobs(jobs1)
        let envelope1 = try await sut.loadCachedJobs()
        XCTAssertEqual(envelope1?.jobs.count, 1)
        XCTAssertEqual(envelope1?.jobs[0].id, "1")

        // Clear between cycles
        try await sut.clearCache()
        let result = try await sut.loadCachedJobs()
        XCTAssertNil(result)

        // Cycle 2
        let jobs2 = [makeJob(id: "a"), makeJob(id: "b")]
        try await sut.cacheJobs(jobs2)
        let envelope2 = try await sut.loadCachedJobs()
        XCTAssertEqual(envelope2?.jobs.count, 2)
        XCTAssertEqual(envelope2?.jobs[0].id, "a")
        XCTAssertEqual(envelope2?.jobs[1].id, "b")

        // Clear between cycles
        try await sut.clearCache()

        // Cycle 3
        let jobs3 = [makeJob(id: "x")]
        try await sut.cacheJobs(jobs3)
        let envelope3 = try await sut.loadCachedJobs()
        XCTAssertEqual(envelope3?.jobs.count, 1)
        XCTAssertEqual(envelope3?.jobs[0].id, "x")
    }

    // MARK: - Clear Cache on Empty Cache

    func testClearCacheOnEmptyCacheDoesNotThrow() async {
        XCTAssertFalse(sut.hasCachedJobs())
        do {
            try await sut.clearCache()
        } catch {
            XCTFail("clearCache should not throw on empty cache: \(error)")
        }
    }

    // MARK: - CachedJobsEnvelope Properties

    func testCachedAtDateIsRecent() async throws {
        let before = Date().addingTimeInterval(-1)
        try await sut.cacheJobs([makeJob()])
        let after = Date().addingTimeInterval(1)

        let envelope = try await sut.loadCachedJobs()
        XCTAssertNotNil(envelope)
        XCTAssertGreaterThanOrEqual(envelope!.cachedAt, before)
        XCTAssertLessThanOrEqual(envelope!.cachedAt, after)
    }

    func testRelativeCacheTimeIsNotEmpty() async throws {
        try await sut.cacheJobs([makeJob()])
        let envelope = try await sut.loadCachedJobs()
        XCTAssertNotNil(envelope)
        XCTAssertFalse(envelope!.relativeCacheTime.isEmpty)
    }

    // MARK: - Cache Isolation Between Instances

    func testSeparateInstancesShareSameCacheDirectory() async throws {
        let jobs = [makeJob(id: "shared")]
        try await sut.cacheJobs(jobs)

        let otherInstance = CacheService(cacheDirectory: cacheDirectory)
        XCTAssertTrue(otherInstance.hasCachedJobs())

        let envelope = try await otherInstance.loadCachedJobs()
        XCTAssertNotNil(envelope)
        XCTAssertEqual(envelope!.jobs[0].id, "shared")
    }
}
