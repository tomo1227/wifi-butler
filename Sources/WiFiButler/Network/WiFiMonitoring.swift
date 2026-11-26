import ButlerCore

@MainActor
protocol WiFiMonitoring {
  var canReconnect: Bool { get }
  var hasWiFiRoute: Bool { get }

  func start(onChange: @escaping @MainActor @Sendable () -> Void)
  func requestLocationPermission()
  func snapshot() -> WiFiSnapshot
}
