import CoreWLAN
import OSLog
import Observation

@MainActor
@Observable
final class WiFiSpeedTestModel {
  enum State: Equatable {
    case ready
    case measuring
    case completed(WiFiSpeedTestResult)
    case noWiFi
    case failed
  }

  private(set) var state: State = .ready
  private let interfaceName: () -> String?
  private let measure: (String) async throws -> WiFiSpeedTestResult
  private let logger = Logger(subsystem: "dev.wifibutler.app", category: "network")

  init(
    interfaceName: @escaping () -> String? = {
      guard let wifi = CWWiFiClient.shared().interface(), wifi.powerOn(),
        wifi.interfaceMode() == .station
      else { return nil }
      return wifi.interfaceName
    },
    measure: @escaping (String) async throws -> WiFiSpeedTestResult = WiFiSpeedTest.measure
  ) {
    self.interfaceName = interfaceName
    self.measure = measure
  }

  func start() {
    guard state != .measuring else { return }
    guard let name = interfaceName(), !name.isEmpty else {
      state = .noWiFi
      return
    }
    state = .measuring
    Task {
      do {
        state = .completed(try await measure(name))
      } catch {
        logger.error("Wi-Fi speed test failed: \(String(describing: error), privacy: .private)")
        state = .failed
      }
    }
  }
}
