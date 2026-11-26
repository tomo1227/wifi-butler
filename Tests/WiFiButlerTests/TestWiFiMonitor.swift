import ButlerCore

@testable import WiFiButler

@MainActor
final class TestWiFiMonitor: WiFiMonitoring {
  let canReconnect = false
  let hasWiFiRoute = false
  private var current: WiFiSnapshot
  private var onChange: (@MainActor @Sendable () -> Void)?
  private(set) var permissionRequests = 0

  init(current: WiFiSnapshot) {
    self.current = current
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
