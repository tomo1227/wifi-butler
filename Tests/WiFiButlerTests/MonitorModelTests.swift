import ButlerCore
import XCTest

@testable import WiFiButler

final class MonitorModelTests: XCTestCase {
  @MainActor
  func testReconnectFailureIsHiddenIfStillConnectedToSameSSID() async throws {
    let wifi = TestWiFiMonitor(current: .connected("Home"), canReconnect: true)
    let model = MonitorModel(wifi: wifi, reconnectWiFi: { _, _ in .failed })
    model.startObservingWiFi()
    try await waitForCheck(model)

    model.reconnect()
    XCTAssertEqual(model.status, .reconnecting)
    try await waitForCheck(model)

    XCTAssertEqual(model.snapshot, .connected("Home"))
    XCTAssertFalse(model.reconnectFailed)
  }

  @MainActor
  func testReconnectFailureWhileDisconnectedClearsWhenWiFiReturnsWithoutSSID() async throws {
    let wifi = TestWiFiMonitor(current: .connected("Home"), canReconnect: true)
    let model = MonitorModel(wifi: wifi, reconnectWiFi: { _, _ in .failed })
    model.startObservingWiFi()
    try await waitForCheck(model)

    wifi.update(.disconnected)
    try await waitForCheck(model)
    XCTAssertEqual(model.status, .disconnected)
    XCTAssertTrue(model.reconnectFailed)

    wifi.update(.unidentified)
    try await waitForCheck(model)
    XCTAssertEqual(model.status, .unidentified)
    XCTAssertFalse(model.reconnectFailed)

    model.autoReconnect = false
    wifi.update(.disconnected)
    try await waitForCheck(model)
    XCTAssertFalse(model.reconnectFailed)
  }

  @MainActor
  private func waitForCheck(_ model: MonitorModel) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while model.nextCheck == nil, ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(5))
    }
    _ = try XCTUnwrap(model.nextCheck, "Expected a completed connectivity check")
  }

  @MainActor
  func testStartsAtLaunchWhenAlreadyConnected() {
    let wifi = TestWiFiMonitor(current: .connected("Home"))
    let model = MonitorModel(wifi: wifi)

    model.startObservingWiFi()

    XCTAssertTrue(model.isMonitoring)
    XCTAssertEqual(wifi.permissionRequests, 1)
  }

  @MainActor
  func testWaitsForWiFiThenStartsWhenConnected() {
    let wifi = TestWiFiMonitor(current: .disconnected)
    let model = MonitorModel(wifi: wifi)

    model.startObservingWiFi()

    XCTAssertFalse(model.isMonitoring)
    XCTAssertEqual(model.status, .disconnected)
    XCTAssertEqual(wifi.permissionRequests, 0)

    wifi.update(.connected("Home"))

    XCTAssertTrue(model.isMonitoring)
    XCTAssertEqual(wifi.permissionRequests, 1)

    wifi.update(.disconnected)
    wifi.update(.connected("Office"))

    XCTAssertTrue(model.isMonitoring)
    XCTAssertEqual(wifi.permissionRequests, 1)
  }

  @MainActor
  func testStartsEvenBeforeSSIDIsAvailable() {
    let wifi = TestWiFiMonitor(current: .disconnected)
    let model = MonitorModel(wifi: wifi)
    model.startObservingWiFi()

    wifi.update(.unidentified)

    XCTAssertTrue(model.isMonitoring)
    XCTAssertEqual(wifi.permissionRequests, 1)

    wifi.update(.connected("Home"))

    XCTAssertTrue(model.isMonitoring)
    XCTAssertEqual(wifi.permissionRequests, 1)
  }

  @MainActor
  func testManualStopPersistsAcrossNetworkChangesAndWake() {
    let wifi = TestWiFiMonitor(current: .connected("Home"))
    let model = MonitorModel(wifi: wifi)
    model.startObservingWiFi()

    model.setMonitoring(false)
    wifi.update(.disconnected)
    model.setSleeping(true)
    wifi.update(.connected("Office"))
    model.setSleeping(false)
    wifi.update(.connected("Home"))

    XCTAssertFalse(model.isMonitoring)
    XCTAssertEqual(model.status, .paused)
    XCTAssertEqual(wifi.permissionRequests, 1)

    model.setMonitoring(true)

    XCTAssertTrue(model.isMonitoring)
    XCTAssertEqual(wifi.permissionRequests, 2)
  }

  @MainActor
  func testStartsOnWakeIfWiFiConnectedWhileWaiting() {
    let wifi = TestWiFiMonitor(current: .disconnected)
    let model = MonitorModel(wifi: wifi)
    model.startObservingWiFi()

    model.setSleeping(true)
    wifi.update(.connected("Home"))

    XCTAssertFalse(model.isMonitoring)

    model.setSleeping(false)

    XCTAssertTrue(model.isMonitoring)
  }
}
