// ApplicationStatusManagerTests.swift
// RemoteRecruitTests

import XCTest
@testable import RemoteRecruit

// MARK: - ApplicationStatusManager Tests

final class ApplicationStatusManagerTests: XCTestCase {

    private let manager = ApplicationStatusManager()

    // MARK: - Valid Transitions from .applied

    func testAppliedToViewed() throws {
        let result = try manager.transition(from: .applied, to: .viewed)
        XCTAssertEqual(result, .viewed)
    }

    func testAppliedToInterviewScheduled() throws {
        let result = try manager.transition(from: .applied, to: .interviewScheduled)
        XCTAssertEqual(result, .interviewScheduled)
    }

    func testAppliedToShortlisted() throws {
        let result = try manager.transition(from: .applied, to: .shortlisted)
        XCTAssertEqual(result, .shortlisted)
    }

    func testAppliedToRejected() throws {
        let result = try manager.transition(from: .applied, to: .rejected)
        XCTAssertEqual(result, .rejected)
    }

    // MARK: - Valid Transitions from .viewed

    func testViewedToInterviewScheduled() throws {
        let result = try manager.transition(from: .viewed, to: .interviewScheduled)
        XCTAssertEqual(result, .interviewScheduled)
    }

    func testViewedToShortlisted() throws {
        let result = try manager.transition(from: .viewed, to: .shortlisted)
        XCTAssertEqual(result, .shortlisted)
    }

    func testViewedToRejected() throws {
        let result = try manager.transition(from: .viewed, to: .rejected)
        XCTAssertEqual(result, .rejected)
    }

    // MARK: - Valid Transitions from .interviewScheduled

    func testInterviewScheduledToShortlisted() throws {
        let result = try manager.transition(from: .interviewScheduled, to: .shortlisted)
        XCTAssertEqual(result, .shortlisted)
    }

    func testInterviewScheduledToRejected() throws {
        let result = try manager.transition(from: .interviewScheduled, to: .rejected)
        XCTAssertEqual(result, .rejected)
    }

    func testInterviewScheduledToOfferReceived() throws {
        let result = try manager.transition(from: .interviewScheduled, to: .offerReceived)
        XCTAssertEqual(result, .offerReceived)
    }

    // MARK: - Valid Transitions from .shortlisted

    func testShortlistedToRejected() throws {
        let result = try manager.transition(from: .shortlisted, to: .rejected)
        XCTAssertEqual(result, .rejected)
    }

    func testShortlistedToOfferReceived() throws {
        let result = try manager.transition(from: .shortlisted, to: .offerReceived)
        XCTAssertEqual(result, .offerReceived)
    }

    // MARK: - Invalid Transitions

    func testRejectedToAppliedThrowsError() {
        XCTAssertThrowsError(try manager.transition(from: .rejected, to: .applied)) { error in
            XCTAssertTrue(error is StatusTransitionError)
        }
    }

    func testOfferReceivedToShortlistedThrowsError() {
        XCTAssertThrowsError(try manager.transition(from: .offerReceived, to: .shortlisted)) { error in
            XCTAssertTrue(error is StatusTransitionError)
        }
    }

    func testAppliedToOfferReceivedThrowsError() {
        XCTAssertThrowsError(try manager.transition(from: .applied, to: .offerReceived)) { error in
            XCTAssertTrue(error is StatusTransitionError)
        }
    }

    func testRejectedToOfferReceivedThrowsError() {
        XCTAssertThrowsError(try manager.transition(from: .rejected, to: .offerReceived)) { error in
            XCTAssertTrue(error is StatusTransitionError)
        }
    }

    func testOfferReceivedToAppliedThrowsError() {
        XCTAssertThrowsError(try manager.transition(from: .offerReceived, to: .applied)) { error in
            XCTAssertTrue(error is StatusTransitionError)
        }
    }

    func testViewedToAppliedThrowsError() {
        XCTAssertThrowsError(try manager.transition(from: .viewed, to: .applied)) { error in
            XCTAssertTrue(error is StatusTransitionError)
        }
    }

    // MARK: - Same-State Transition

    func testSameStateTransitionIsInvalid() {
        XCTAssertThrowsError(try manager.transition(from: .applied, to: .applied)) { error in
            XCTAssertTrue(error is StatusTransitionError)
        }
    }

    func testSameStateRejectedThrowsError() {
        XCTAssertThrowsError(try manager.transition(from: .rejected, to: .rejected)) { error in
            XCTAssertTrue(error is StatusTransitionError)
        }
    }

    func testSameStateOfferReceivedThrowsError() {
        XCTAssertThrowsError(try manager.transition(from: .offerReceived, to: .offerReceived)) { error in
            XCTAssertTrue(error is StatusTransitionError)
        }
    }

    // MARK: - availableTransitions

    func testAvailableTransitionsFromApplied() {
        let transitions = manager.availableTransitions(from: .applied)
        XCTAssertEqual(transitions.count, 4)
        XCTAssertTrue(transitions.contains(.viewed))
        XCTAssertTrue(transitions.contains(.interviewScheduled))
        XCTAssertTrue(transitions.contains(.shortlisted))
        XCTAssertTrue(transitions.contains(.rejected))
    }

    func testAvailableTransitionsFromViewed() {
        let transitions = manager.availableTransitions(from: .viewed)
        XCTAssertEqual(transitions.count, 3)
        XCTAssertTrue(transitions.contains(.interviewScheduled))
        XCTAssertTrue(transitions.contains(.shortlisted))
        XCTAssertTrue(transitions.contains(.rejected))
    }

    func testAvailableTransitionsFromInterviewScheduled() {
        let transitions = manager.availableTransitions(from: .interviewScheduled)
        XCTAssertEqual(transitions.count, 3)
        XCTAssertTrue(transitions.contains(.shortlisted))
        XCTAssertTrue(transitions.contains(.rejected))
        XCTAssertTrue(transitions.contains(.offerReceived))
    }

    func testAvailableTransitionsFromShortlisted() {
        let transitions = manager.availableTransitions(from: .shortlisted)
        XCTAssertEqual(transitions.count, 2)
        XCTAssertTrue(transitions.contains(.rejected))
        XCTAssertTrue(transitions.contains(.offerReceived))
    }

    func testAvailableTransitionsFromRejectedIsEmpty() {
        let transitions = manager.availableTransitions(from: .rejected)
        XCTAssertTrue(transitions.isEmpty)
    }

    func testAvailableTransitionsFromOfferReceivedIsEmpty() {
        let transitions = manager.availableTransitions(from: .offerReceived)
        XCTAssertTrue(transitions.isEmpty)
    }

    // MARK: - StatusTransitionError Description

    func testStatusTransitionErrorDescription() {
        let error = StatusTransitionError.invalidTransition(from: .rejected, to: .applied)
        XCTAssertEqual(
            error.errorDescription,
            "Cannot transition from Rejected to Applied."
        )
    }

    func testStatusTransitionErrorLocalizedDescription() {
        let error = StatusTransitionError.invalidTransition(from: .applied, to: .offerReceived)
        XCTAssertEqual(
            error.localizedDescription,
            "Cannot transition from Applied to Offer Received."
        )
    }

    // MARK: - ExtendedApplicationStatus Properties

    func testAppliedDisplayName() {
        XCTAssertEqual(ExtendedApplicationStatus.applied.displayName, "Applied")
    }

    func testViewedDisplayName() {
        XCTAssertEqual(ExtendedApplicationStatus.viewed.displayName, "Viewed")
    }

    func testInterviewScheduledDisplayName() {
        XCTAssertEqual(ExtendedApplicationStatus.interviewScheduled.displayName, "Interview Scheduled")
    }

    func testShortlistedDisplayName() {
        XCTAssertEqual(ExtendedApplicationStatus.shortlisted.displayName, "Shortlisted")
    }

    func testRejectedDisplayName() {
        XCTAssertEqual(ExtendedApplicationStatus.rejected.displayName, "Rejected")
    }

    func testOfferReceivedDisplayName() {
        XCTAssertEqual(ExtendedApplicationStatus.offerReceived.displayName, "Offer Received")
    }

    // MARK: - shortTag

    func testAppliedShortTag() {
        XCTAssertEqual(ExtendedApplicationStatus.applied.shortTag, "APPLIED")
    }

    func testViewedShortTag() {
        XCTAssertEqual(ExtendedApplicationStatus.viewed.shortTag, "VIEWED")
    }

    func testInterviewScheduledShortTag() {
        XCTAssertEqual(ExtendedApplicationStatus.interviewScheduled.shortTag, "INTERVIEW")
    }

    func testShortlistedShortTag() {
        XCTAssertEqual(ExtendedApplicationStatus.shortlisted.shortTag, "SHORTLISTED")
    }

    func testRejectedShortTag() {
        XCTAssertEqual(ExtendedApplicationStatus.rejected.shortTag, "REJECTED")
    }

    func testOfferReceivedShortTag() {
        XCTAssertEqual(ExtendedApplicationStatus.offerReceived.shortTag, "OFFER")
    }

    // MARK: - iconName

    func testAppliedIconName() {
        XCTAssertEqual(ExtendedApplicationStatus.applied.iconName, "paperplane.fill")
    }

    func testViewedIconName() {
        XCTAssertEqual(ExtendedApplicationStatus.viewed.iconName, "eye.fill")
    }

    func testInterviewScheduledIconName() {
        XCTAssertEqual(ExtendedApplicationStatus.interviewScheduled.iconName, "calendar.badge.clock")
    }

    func testShortlistedIconName() {
        XCTAssertEqual(ExtendedApplicationStatus.shortlisted.iconName, "star.fill")
    }

    func testRejectedIconName() {
        XCTAssertEqual(ExtendedApplicationStatus.rejected.iconName, "xmark.circle.fill")
    }

    func testOfferReceivedIconName() {
        XCTAssertEqual(ExtendedApplicationStatus.offerReceived.iconName, "gift.fill")
    }

    // MARK: - colorName

    func testAppliedColorName() {
        XCTAssertEqual(ExtendedApplicationStatus.applied.colorName, "blue")
    }

    func testViewedColorName() {
        XCTAssertEqual(ExtendedApplicationStatus.viewed.colorName, "indigo")
    }

    func testInterviewScheduledColorName() {
        XCTAssertEqual(ExtendedApplicationStatus.interviewScheduled.colorName, "purple")
    }

    func testShortlistedColorName() {
        XCTAssertEqual(ExtendedApplicationStatus.shortlisted.colorName, "green")
    }

    func testRejectedColorName() {
        XCTAssertEqual(ExtendedApplicationStatus.rejected.colorName, "red")
    }

    func testOfferReceivedColorName() {
        XCTAssertEqual(ExtendedApplicationStatus.offerReceived.colorName, "orange")
    }

    // MARK: - sortPriority

    func testSortPriorityOrdering() {
        // Lower = higher priority
        XCTAssertLessThan(ExtendedApplicationStatus.offerReceived.sortPriority, ExtendedApplicationStatus.interviewScheduled.sortPriority)
        XCTAssertLessThan(ExtendedApplicationStatus.interviewScheduled.sortPriority, ExtendedApplicationStatus.shortlisted.sortPriority)
        XCTAssertLessThan(ExtendedApplicationStatus.shortlisted.sortPriority, ExtendedApplicationStatus.viewed.sortPriority)
        XCTAssertLessThan(ExtendedApplicationStatus.viewed.sortPriority, ExtendedApplicationStatus.applied.sortPriority)
        XCTAssertLessThan(ExtendedApplicationStatus.applied.sortPriority, ExtendedApplicationStatus.rejected.sortPriority)
    }

    func testOfferReceivedSortPriorityIsZero() {
        XCTAssertEqual(ExtendedApplicationStatus.offerReceived.sortPriority, 0)
    }

    func testRejectedSortPriorityIsHighest() {
        XCTAssertEqual(ExtendedApplicationStatus.rejected.sortPriority, 5)
    }

    // MARK: - canTransition

    func testCanTransitionAppliedToViewed() {
        XCTAssertTrue(ExtendedApplicationStatus.applied.canTransition(to: .viewed))
    }

    func testCanTransitionAppliedToInterviewScheduled() {
        XCTAssertTrue(ExtendedApplicationStatus.applied.canTransition(to: .interviewScheduled))
    }

    func testCanTransitionAppliedToOfferReceived() {
        XCTAssertFalse(ExtendedApplicationStatus.applied.canTransition(to: .offerReceived))
    }

    func testCanTransitionViewedToApplied() {
        XCTAssertFalse(ExtendedApplicationStatus.viewed.canTransition(to: .applied))
    }

    func testCanTransitionRejectedToAnything() {
        XCTAssertFalse(ExtendedApplicationStatus.rejected.canTransition(to: .applied))
        XCTAssertFalse(ExtendedApplicationStatus.rejected.canTransition(to: .viewed))
        XCTAssertFalse(ExtendedApplicationStatus.rejected.canTransition(to: .interviewScheduled))
        XCTAssertFalse(ExtendedApplicationStatus.rejected.canTransition(to: .shortlisted))
        XCTAssertFalse(ExtendedApplicationStatus.rejected.canTransition(to: .offerReceived))
        XCTAssertFalse(ExtendedApplicationStatus.rejected.canTransition(to: .rejected))
    }

    func testCanTransitionOfferReceivedToAnything() {
        XCTAssertFalse(ExtendedApplicationStatus.offerReceived.canTransition(to: .applied))
        XCTAssertFalse(ExtendedApplicationStatus.offerReceived.canTransition(to: .viewed))
        XCTAssertFalse(ExtendedApplicationStatus.offerReceived.canTransition(to: .interviewScheduled))
        XCTAssertFalse(ExtendedApplicationStatus.offerReceived.canTransition(to: .shortlisted))
        XCTAssertFalse(ExtendedApplicationStatus.offerReceived.canTransition(to: .rejected))
        XCTAssertFalse(ExtendedApplicationStatus.offerReceived.canTransition(to: .offerReceived))
    }

    func testCanTransitionShortlistedToOfferReceived() {
        XCTAssertTrue(ExtendedApplicationStatus.shortlisted.canTransition(to: .offerReceived))
    }

    // MARK: - Identifiable

    func testStatusIdMatchesRawValue() {
        XCTAssertEqual(ExtendedApplicationStatus.applied.id, "applied")
        XCTAssertEqual(ExtendedApplicationStatus.interviewScheduled.id, "interview_scheduled")
        XCTAssertEqual(ExtendedApplicationStatus.offerReceived.id, "offer_received")
    }

    // MARK: - Equatable

    func testStatusEquality() {
        XCTAssertEqual(ExtendedApplicationStatus.applied, .applied)
        XCTAssertNotEqual(ExtendedApplicationStatus.applied, .viewed)
    }
}
