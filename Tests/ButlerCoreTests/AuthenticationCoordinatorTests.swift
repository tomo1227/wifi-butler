import ButlerCore
import XCTest

final class AuthenticationCoordinatorTests: XCTestCase {
  private let network = WiFiSnapshot.connected("Cafe")
  private let page = URL(string: "https://example.test/terms")!
  private var policy: PortalPolicy? {
    PortalPolicy(ssid: "Cafe", page: page.absoluteString, button: "Agree")
  }

  func testRequiresRepeatedEvidenceAndOnlyOffersOnce() {
    var coordinator = AuthenticationCoordinator()
    coordinator.networkChanged(to: network)
    XCTAssertEqual(
      coordinator.observe(.portal(page), policy: policy, requireConfirmation: true), .none)
    XCTAssertEqual(
      coordinator.observe(.portal(page), policy: policy, requireConfirmation: true), .confirm(page))
    XCTAssertEqual(
      coordinator.observe(.portal(page), policy: policy, requireConfirmation: true), .none)
    XCTAssertFalse(coordinator.interactionStarted)
  }

  func testUnknownNetworkAndUnapprovedURLNeverAutomate() {
    var coordinator = AuthenticationCoordinator()
    coordinator.networkChanged(to: .unidentified)
    for _ in 0..<3 {
      XCTAssertEqual(
        coordinator.observe(.portal(page), policy: policy, requireConfirmation: false), .none)
    }
    coordinator.networkChanged(to: network)
    let otherPage = URL(string: "https://example.test/other")!
    for _ in 0..<3 {
      XCTAssertEqual(
        coordinator.observe(.portal(otherPage), policy: policy, requireConfirmation: false), .none)
      XCTAssertEqual(
        coordinator.observe(.portal(page), policy: nil, requireConfirmation: false), .none)
    }
  }

  func testTemporaryFailureDoesNotResetAttemptButOnlineDoes() {
    var coordinator = AuthenticationCoordinator()
    coordinator.networkChanged(to: network)
    _ = coordinator.observe(.portal(page), policy: policy, requireConfirmation: false)
    XCTAssertEqual(
      coordinator.observe(.portal(page), policy: policy, requireConfirmation: false),
      .automate(page))
    coordinator.recordInteraction()
    coordinator.networkChanged(to: .disconnected)
    coordinator.networkChanged(to: network)
    _ = coordinator.observe(.unavailable, policy: policy, requireConfirmation: false)
    for _ in 0..<3 {
      XCTAssertEqual(
        coordinator.observe(.portal(page), policy: policy, requireConfirmation: false), .none)
    }
    XCTAssertTrue(coordinator.interactionStarted)
    _ = coordinator.observe(.online, policy: policy, requireConfirmation: false)
    XCTAssertFalse(coordinator.interactionStarted)
    _ = coordinator.observe(.portal(page), policy: policy, requireConfirmation: false)
    XCTAssertEqual(
      coordinator.observe(.portal(page), policy: policy, requireConfirmation: false),
      .automate(page))
  }
}
