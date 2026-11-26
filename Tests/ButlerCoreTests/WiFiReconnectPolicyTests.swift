import ButlerCore
import Foundation
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

  func testConnectedRecoveryRunsOnceUntilInternetReturns() throws {
    var policy = WiFiReconnectPolicy()
    let current = WiFiSnapshot.connected(ssid)
    let portal = try XCTUnwrap(URL(string: "http://login.example.com"))
    policy.observe(current)

    policy.observeConnectivity(.portal(portal))
    XCTAssertNil(policy.takeRecoveryTarget(for: current))
    policy.observe(current)
    policy.observeConnectivity(.portal(portal))
    XCTAssertEqual(policy.takeRecoveryTarget(for: current), ssid)
    XCTAssertNil(policy.takeAutomaticTarget(for: .disconnected))

    policy.observe(current)
    policy.observeConnectivity(.unavailable)
    policy.observeConnectivity(.unavailable)
    XCTAssertNil(policy.takeRecoveryTarget(for: current))

    policy.observeConnectivity(.online)
    policy.observeConnectivity(.unavailable)
    XCTAssertNil(policy.takeRecoveryTarget(for: current))
    policy.observeConnectivity(.unavailable)
    XCTAssertEqual(policy.takeRecoveryTarget(for: current), ssid)
  }

  func testConnectedRecoveryRequiresConsecutiveFailuresOnSameSSID() {
    var policy = WiFiReconnectPolicy()
    policy.observe(.connected(ssid))
    policy.observeConnectivity(.unavailable)

    let current = WiFiSnapshot.connected("OtherFreeWiFi")
    policy.observe(current)
    policy.observeConnectivity(.unavailable)
    XCTAssertNil(policy.takeRecoveryTarget(for: current))
    policy.observeConnectivity(.online)
    policy.observeConnectivity(.unavailable)
    XCTAssertNil(policy.takeRecoveryTarget(for: current))
    policy.observeConnectivity(.unexpectedResponse)
    XCTAssertEqual(policy.takeRecoveryTarget(for: current), "OtherFreeWiFi")
  }
}
