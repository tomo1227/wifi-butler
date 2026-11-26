import ButlerCore
import XCTest

@testable import WiFiButler

final class MonitorModelTests: XCTestCase {
  @MainActor
  func testUnreachableOpenWiFiForcesOneReconnectWithoutAnSSIDChange() async throws {
    try await assertConnectedRecovery(for: .unavailable, probeStatus: .unavailable)
  }

  @MainActor
  func testCaptivePortalForcesOneReconnectWithoutAnSSIDChange() async throws {
    let url = try XCTUnwrap(URL(string: "http://login.example.com"))
    try await assertConnectedRecovery(for: .portal(url), probeStatus: .checking)
  }

  @MainActor
  private func assertConnectedRecovery(for result: Connectivity, probeStatus: MonitorStatus)
    async throws
  {
    let wifi = TestWiFiMonitor(current: .connected("Cafe"), canReconnect: true, hasWiFiRoute: true)
    let attempts = ReconnectAttempts()
    let model = MonitorModel(
      wifi: wifi,
      reconnectWiFi: { ssid, force in
        XCTAssertEqual(ssid, "Cafe")
        await attempts.record(force: force)
        return .failed
      },
      checkConnectivity: { _ in result }
    )
    defer { model.setMonitoring(false) }
    model.startObservingWiFi()
    try await waitForCheck(model)
    XCTAssertEqual(model.status, probeStatus)
    let initialAttempts = await attempts.forceFlags
    XCTAssertTrue(initialAttempts.isEmpty)

    model.refresh()
    try await waitForCheck(model)
    XCTAssertEqual(model.snapshot, .connected("Cafe"))
    XCTAssertEqual(model.status, probeStatus)
    let attemptsAfterFailure = await attempts.forceFlags
    XCTAssertEqual(attemptsAfterFailure, [true])

    model.refresh()
    try await waitForCheck(model)
    let attemptsAfterRecheck = await attempts.forceFlags
    XCTAssertEqual(attemptsAfterRecheck, [true])
  }

  @MainActor
  func testUnreachableWiFiDoesNotReconnectWhenDisabledOrSecured() async throws {
    for (autoReconnect, isOpenNetwork) in [(false, true), (true, false)] {
      let wifi = TestWiFiMonitor(
        current: .connected("Cafe"), canReconnect: true, hasWiFiRoute: true,
        isOnOpenNetwork: isOpenNetwork
      )
      let model = MonitorModel(
        wifi: wifi,
        reconnectWiFi: { _, _ in
          XCTFail("Unexpected automatic reconnect")
          return .failed
        },
        checkConnectivity: { _ in .unavailable }
      )
      defer { model.setMonitoring(false) }
      model.autoReconnect = autoReconnect
      model.startObservingWiFi()
      try await waitForCheck(model)

      model.refresh()
      try await waitForCheck(model)
      XCTAssertEqual(model.status, .unavailable)
    }
  }

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

  private actor ReconnectAttempts {
    private(set) var forceFlags: [Bool] = []

    func record(force: Bool) {
      forceFlags.append(force)
    }
  }
}
