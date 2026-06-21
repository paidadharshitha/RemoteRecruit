// SearchViewModelTests.swift
// RemoteRecruitTests

import XCTest
@testable import RemoteRecruit

// MARK: - Tests

@MainActor
final class SearchViewModelTests: XCTestCase {

    private var historyService: SearchHistoryService!

    // MARK: - setUp / tearDown

    override func setUp() {
        historyService = SearchHistoryService(searches: [])
    }

    override func tearDown() {
        historyService = nil
    }

    private func makeViewModel(searches: [String] = []) -> SearchViewModel {
        historyService = SearchHistoryService(searches: searches)
        return SearchViewModel(historyService: historyService)
    }

    // MARK: - Initial State

    func testInitialStateHasEmptySearchText() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.searchText, "")
    }

    func testInitialRecentSearchesReflectsHistoryService() {
        let vm = makeViewModel(searches: ["Swift", "iOS", "SwiftUI"])
        XCTAssertEqual(vm.recentSearches, ["Swift", "iOS", "SwiftUI"])
    }

    // MARK: - selectRecentSearch

    func testSelectRecentSearchSetsSearchText() {
        let vm = makeViewModel(searches: ["iOS Developer"])
        vm.selectRecentSearch("iOS Developer")
        XCTAssertEqual(vm.searchText, "iOS Developer")
    }

    func testSelectRecentSearchMovesQueryToTop() {
        let vm = makeViewModel(searches: ["Swift", "iOS", "Combine"])
        vm.selectRecentSearch("Combine")
        XCTAssertEqual(vm.recentSearches.first, "Combine")
        // Original count preserved (not duplicated)
        XCTAssertEqual(vm.recentSearches.count, 3)
    }

    func testSelectRecentSearchSetsIsSearchFocusedToFalse() {
        let vm = makeViewModel(searches: ["iOS"])
        vm.isSearchFocused = true
        vm.selectRecentSearch("iOS")
        XCTAssertFalse(vm.isSearchFocused)
    }

    func testSelectRecentSearchAddsNewQueryToHistory() {
        let vm = makeViewModel(searches: ["Swift"])
        vm.selectRecentSearch("New Query")
        XCTAssertTrue(vm.recentSearches.contains("New Query"))
        XCTAssertEqual(vm.recentSearches.first, "New Query")
    }

    // MARK: - removeRecentSearch

    func testRemoveRecentSearchRemovesFromList() {
        let vm = makeViewModel(searches: ["Swift", "iOS", "Combine"])
        vm.removeRecentSearch("iOS")
        XCTAssertFalse(vm.recentSearches.contains("iOS"))
        XCTAssertEqual(vm.recentSearches.count, 2)
    }

    func testRemoveRecentSearchWithNonExistentQueryIsIdempotent() {
        let vm = makeViewModel(searches: ["Swift", "iOS"])
        vm.removeRecentSearch("NonExistent")
        XCTAssertEqual(vm.recentSearches.count, 2)
    }

    // MARK: - clearHistory

    func testClearHistoryEmptiesRecentSearches() {
        let vm = makeViewModel(searches: ["Swift", "iOS", "Combine"])
        vm.clearHistory()
        XCTAssertTrue(vm.recentSearches.isEmpty)
    }

    func testClearHistoryAfterClearHistoryIsIdempotent() {
        let vm = makeViewModel(searches: ["Swift"])
        vm.clearHistory()
        vm.clearHistory()
        XCTAssertTrue(vm.recentSearches.isEmpty)
    }

    // MARK: - clearSearch

    func testClearSearchSetsSearchTextToEmpty() {
        let vm = makeViewModel()
        vm.searchText = "Some query"
        vm.clearSearch()
        XCTAssertEqual(vm.searchText, "")
    }

    // MARK: - recentSearches reflects historyService

    func testRecentSearchesReflectsHistoryServiceState() {
        let vm = makeViewModel(searches: ["Query 1", "Query 2"])
        XCTAssertEqual(vm.recentSearches, ["Query 1", "Query 2"])

        // Use selectRecentSearch to sync history → recentSearches
        vm.selectRecentSearch("Query 3")
        XCTAssertEqual(vm.recentSearches, ["Query 3", "Query 1", "Query 2"])
    }

    // MARK: - Edge Cases

    func testEmptyHistoryReturnsEmptyRecentSearches() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.recentSearches.isEmpty)
    }

    func testRemoveOnlySearchLeavesEmptyHistory() {
        let vm = makeViewModel(searches: ["OnlyQuery"])
        vm.removeRecentSearch("OnlyQuery")
        XCTAssertTrue(vm.recentSearches.isEmpty)
    }
}
