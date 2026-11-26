import ButlerCore
import XCTest

final class PortalFlowTests: XCTestCase {
  private let retries = RetryManager(retries: 0, intervalSeconds: 2)

  @MainActor
  func testSuccessfulPressIsOnlyPerformedOnce() async {
    var presses = 0
    let result = await PortalFlow().run(
      retries: retries, isCurrent: { true }, open: { true },
      press: {
        presses += 1
        return .pressed
      },
      verify: { .online }
    )
    XCTAssertEqual(result, .verified)
    XCTAssertEqual(presses, 1)
  }

  @MainActor
  func testUnverifiedConnectionDoesNotPressAgain() async {
    var presses = 0
    let result = await PortalFlow().run(
      retries: retries, isCurrent: { true }, open: { true },
      press: {
        presses += 1
        return .pressed
      },
      verify: { .unavailable }
    )
    XCTAssertEqual(result, .notVerified)
    XCTAssertEqual(presses, 1)
  }

  @MainActor
  func testMissingPermissionAndAmbiguousButtonsRequireManualAuthentication() async {
    for refusal: PortalButtonResult in [.permissionRequired, .ambiguous, .pressFailed, .notReady] {
      let result = await PortalFlow().run(
        retries: retries, isCurrent: { true }, open: { true },
        press: { refusal },
        verify: {
          XCTFail("Must not proceed without a successful press")
          return .online
        }
      )
      XCTAssertEqual(result, .manualRequired(refusal))
    }
  }

  @MainActor
  func testBrowserLaunchFailureNeverAttemptsToPress() async {
    let result = await PortalFlow().run(
      retries: retries, isCurrent: { true }, open: { false },
      press: {
        XCTFail("Must not press after launch failure")
        return .pressed
      },
      verify: { .online }
    )
    XCTAssertEqual(result, .browserFailed)
  }

  @MainActor
  func testNetworkChangeDuringBrowserLaunchCancelsPress() async {
    var current = true
    let result = await PortalFlow().run(
      retries: retries, isCurrent: { current },
      open: {
        current = false
        return true
      },
      press: {
        XCTFail("Must not act after network change")
        return .pressed
      },
      verify: { .online }
    )
    XCTAssertEqual(result, .cancelled)
  }

  @MainActor
  func testRetryBudgetAndBackoff() async throws {
    var checks = 0
    var intervals: [Duration] = []
    let result: Int? = try await RetryManager(retries: 2, intervalSeconds: 4).run(
      {
        checks += 1
        return nil
      },
      wait: { intervals.append($0) }
    )
    XCTAssertNil(result)
    XCTAssertEqual(checks, 3)
    XCTAssertEqual(intervals, [.seconds(4), .seconds(4)])
  }
}
