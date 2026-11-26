import ButlerCore
import CoreLocation
import CoreWLAN
import Network

@MainActor
final class WiFiMonitor {
  private let location = CLLocationManager()
  private let path = NWPathMonitor()
  private let queue = DispatchQueue(label: "WiFiButler.NetworkPath")
  private let client = CWWiFiClient.shared()

  func start(onChange: @escaping @MainActor @Sendable () -> Void) {
    path.pathUpdateHandler = { _ in Task { @MainActor in onChange() } }
    path.start(queue: queue)
  }

  func requestLocationPermission() {
    location.requestWhenInUseAuthorization()
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
