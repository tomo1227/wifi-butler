import ButlerCore
import CoreLocation
import CoreWLAN
import Network
import OSLog

@MainActor
final class WiFiMonitor: NSObject, WiFiMonitoring, CWEventDelegate, CLLocationManagerDelegate {
  private let location = CLLocationManager()
  private let path = NWPathMonitor()
  private let queue = DispatchQueue(label: "WiFiButler.NetworkPath")
  private let client = CWWiFiClient.shared()
  private let logger = Logger(subsystem: "dev.wifibutler.app", category: "network")
  private var onChange: (@MainActor @Sendable () -> Void)?

  func start(onChange: @escaping @MainActor @Sendable () -> Void) {
    guard self.onChange == nil else { return }
    self.onChange = onChange
    location.delegate = self
    path.pathUpdateHandler = { _ in Task { @MainActor in onChange() } }
    path.start(queue: queue)
    client.delegate = self
    for event: CWEventType in [.ssidDidChange, .linkDidChange] {
      do {
        try client.startMonitoringEvent(with: event)
      } catch {
        logger.error(
          "Could not register Wi-Fi event \(event.rawValue): \(error.localizedDescription)")
      }
    }
  }

  nonisolated func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
    notifyChange()
  }

  nonisolated func linkDidChangeForWiFiInterface(withName interfaceName: String) {
    notifyChange()
  }

  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    notifyChange()
  }

  private nonisolated func notifyChange() {
    Task { @MainActor [weak self] in self?.onChange?() }
  }

  func requestLocationPermission() {
    location.requestWhenInUseAuthorization()
  }

  var canReconnect: Bool {
    location.authorizationStatus == .authorizedAlways && client.interface()?.powerOn() == true
  }

  func snapshot() -> WiFiSnapshot {
    let wifi = client.interface()
    guard wifi?.powerOn() == true else { return .disconnected }
    if let ssid = wifi?.ssid() { return .connected(ssid) }
    if path.currentPath.usesInterfaceType(.wifi) || wifi?.interfaceMode() == .station {
      return .unidentified
    }
    return .disconnected
  }

  var hasWiFiRoute: Bool {
    let current = path.currentPath
    return current.status == .satisfied && current.usesInterfaceType(.wifi)
      && !current.usesInterfaceType(.wiredEthernet)
  }
}
