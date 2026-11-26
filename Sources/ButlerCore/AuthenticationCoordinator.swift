import Foundation

public struct AuthenticationCoordinator: Sendable {
  public enum Action: Equatable, Sendable {
    case none
    case confirm(URL)
    case automate(URL)
  }

  private var network: WiFiSnapshot = .disconnected
  private var evidence = PortalEvidence()
  private var attempted = false
  public private(set) var interactionStarted = false

  public init() {}

  public mutating func networkChanged(to next: WiFiSnapshot) {
    guard next != network else { return }
    evidence = PortalEvidence()
    if case .connected = next, case .connected = network {
      attempted = false
      interactionStarted = false
    }
    // A transient disconnect or hidden SSID is not proof of a new portal episode.
    network = next
  }

  public mutating func observe(
    _ result: Connectivity, policy: PortalPolicy?, requireConfirmation: Bool
  ) -> Action {
    evidence.observe(result)
    if result == .online {
      attempted = false
      interactionStarted = false
    }
    guard let url = evidence.confirmed, !attempted, let policy, policy.permits(url, on: network)
    else { return .none }
    attempted = true
    return requireConfirmation ? .confirm(url) : .automate(url)
  }

  public mutating func recordInteraction() {
    attempted = true
    interactionStarted = true
  }
}
