import ButlerCore
import CoreWLAN
import OSLog

enum WiFiReconnector {
  private static let logger = Logger(subsystem: "dev.wifibutler.app", category: "network")

  enum Outcome {
    case joined, failed, superseded
  }

  static func reconnect(to ssid: String, force: Bool) async -> Outcome {
    let worker = Task.detached(priority: .userInitiated) {
      Self.associate(to: ssid, force: force)
    }
    let outcome = await withTaskCancellationHandler {
      await worker.value
    } onCancel: {
      worker.cancel()
    }
    if case .failed = outcome, !Task.isCancelled {
      logger.error("Wi-Fi reassociation failed")
    }
    return outcome
  }

  private static func associate(to ssid: String, force: Bool) -> Outcome {
    guard let interface = CWWiFiClient.shared().interface(), interface.powerOn()
    else { return .failed }
    guard !Task.isCancelled, canJoin(ssid, on: interface) else { return .superseded }
    if !force, interface.ssid() == ssid { return .joined }

    do {
      let networks = try interface.scanForNetworks(withSSID: Data(ssid.utf8))
      guard !Task.isCancelled, canJoin(ssid, on: interface) else { return .superseded }
      if !force, interface.ssid() == ssid { return .joined }
      guard
        let network = networks.filter({ $0.ssid == ssid && $0.supportsSecurity(.none) })
          .max(by: { $0.rssiValue < $1.rssiValue })
      else { return .failed }
      if interface.ssid() == ssid {
        guard interface.security() == .none else { return .failed }
        interface.disassociate()
      }
      try interface.associate(to: network, password: nil)
      return .joined
    } catch {
      if Task.isCancelled { return .superseded }
      return interface.ssid() == ssid && !force ? .joined : .failed
    }
  }

  private static func canJoin(_ ssid: String, on interface: CWInterface) -> Bool {
    guard interface.powerOn() else { return false }
    if let current = interface.ssid() { return current == ssid }
    return interface.interfaceMode() == .none
  }
}
