import ButlerCore

@testable import WiFiButler

@MainActor
final class TestWiFiMonitor: WiFiMonitoring {
  let canReconnect: Bool
  let hasWiFiRoute: Bool
  let isOnOpenNetwork: Bool
  private var current: WiFiSnapshot
  private var onChange: (@MainActor @Sendable () -> Void)?
  private(set) var permissionRequests = 0

  init(
    current: WiFiSnapshot, canReconnect: Bool = false, hasWiFiRoute: Bool = false,
    isOnOpenNetwork: Bool = true
  ) {
    self.current = current
    self.canReconnect = canReconnect
    self.hasWiFiRoute = hasWiFiRoute
    self.isOnOpenNetwork = isOnOpenNetwork
  }

  func start(onChange: @escaping @MainActor @Sendable () -> Void) {
    self.onChange = onChange
  }

  func requestLocationPermission() {
    permissionRequests += 1
  }

  func snapshot() -> WiFiSnapshot {
    current
  }

  func update(_ snapshot: WiFiSnapshot) {
    current = snapshot
    onChange?()
  }
}
