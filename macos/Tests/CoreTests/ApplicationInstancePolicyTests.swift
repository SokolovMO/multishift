import XCTest
@testable import MultiShiftCore

final class ApplicationInstancePolicyTests: XCTestCase {
    func testDeadPreviousProcessDoesNotCloseRelaunchedApp() {
        var activated = false
        XCTAssertFalse(ApplicationInstancePolicy.shouldYield(isTerminated: false,
            isAlive: { false }, activate: { activated = true; return false }))
        XCTAssertFalse(activated)
    }

    func testProcessExitingDuringActivationDoesNotCloseRelaunchedApp() {
        var checks = [true, false].makeIterator()
        XCTAssertFalse(ApplicationInstancePolicy.shouldYield(isTerminated: false,
            isAlive: { checks.next()! }, activate: { false }))
    }

    func testLiveInstanceStillPreventsDuplicateInputMonitoring() {
        XCTAssertTrue(ApplicationInstancePolicy.shouldYield(isTerminated: false,
            isAlive: { true }, activate: { true }))
        XCTAssertTrue(ApplicationInstancePolicy.shouldYield(isTerminated: false,
            isAlive: { true }, activate: { false }))
    }

    func testTerminatedEntryIsIgnored() {
        XCTAssertFalse(ApplicationInstancePolicy.shouldYield(isTerminated: true,
            isAlive: { XCTFail("must not probe a terminated application"); return true },
            activate: { XCTFail("must not activate a terminated application"); return true }))
    }
}
