import ButlerCore
import XCTest

final class WiFiReconnectPolicyTests: XCTestCase {
  private let ssid = "Shinkansen_Free_Wi-Fi"

  func testManualTargetIncludesAnySSID() {
    var policy = WiFiReconnectPolicy()
    XCTAssertNil(policy.manualTarget(for: .disconnected))
    XCTAssertEqual(policy.manualTarget(for: .connected(ssid)), ssid)
    XCTAssertEqual(policy.manualTarget(for: .connected("Home")), "Home")

    policy.observe(.connected(ssid))
    XCTAssertEqual(policy.manualTarget(for: .disconnected), ssid)
    XCTAssertNil(policy.manualTarget(for: .unidentified))
  }

  func testAutomaticReconnectRunsOncePerDisconnection() {
    var policy = WiFiReconnectPolicy()
    policy.observe(.connected(ssid))
    XCTAssertNil(policy.takeAutomaticTarget(for: .connected(ssid)))
    XCTAssertNil(policy.takeAutomaticTarget(for: .unidentified))
    XCTAssertEqual(policy.takeAutomaticTarget(for: .disconnected), ssid)
    XCTAssertNil(policy.takeAutomaticTarget(for: .disconnected))
    XCTAssertEqual(policy.manualTarget(for: .disconnected), ssid)

    policy.observe(.connected(ssid))
    XCTAssertEqual(policy.takeAutomaticTarget(for: .disconnected), ssid)
  }

  func testManualAttemptDoesNotImmediatelyTriggerAnAutomaticRetry() {
    var policy = WiFiReconnectPolicy()
    policy.observe(.connected(ssid))
    policy.markAttempt(for: ssid)
    XCTAssertNil(policy.takeAutomaticTarget(for: .disconnected))
  }

  func testSwitchingToAnyNetworkKeepsItAsTarget() {
    var policy = WiFiReconnectPolicy()
    policy.observe(.connected(ssid))
    policy.observe(.connected("Home"))
    XCTAssertEqual(policy.manualTarget(for: .disconnected), "Home")
    XCTAssertEqual(policy.takeAutomaticTarget(for: .disconnected), "Home")
  }
}
