public struct WiFiReconnectPolicy: Sendable {
  private var lastSSID: String?
  private var attemptedSSID: String?
  private var didAttemptRecovery = false
  private var connectivityFailures = 0

  public init() {}

  public mutating func observe(_ snapshot: WiFiSnapshot) {
    if case .connected(let ssid) = snapshot {
      if lastSSID != ssid {
        resetConnectivityFailures()
        didAttemptRecovery = false
      }
      lastSSID = ssid
      attemptedSSID = nil
    } else {
      resetConnectivityFailures()
    }
  }

  public mutating func observeConnectivity(_ result: Connectivity) {
    switch result {
    case .online:
      resetConnectivityFailures()
      didAttemptRecovery = false
    case .unavailable, .unexpectedResponse, .portal:
      connectivityFailures = min(connectivityFailures + 1, 2)
    }
  }

  public mutating func resetConnectivityFailures() {
    connectivityFailures = 0
  }

  public mutating func takeRecoveryTarget(for snapshot: WiFiSnapshot) -> String? {
    guard case .connected(let ssid) = snapshot, ssid == lastSSID,
      connectivityFailures >= 2, !didAttemptRecovery
    else { return nil }
    markAttempt(for: ssid)
    return ssid
  }

  public func manualTarget(for snapshot: WiFiSnapshot) -> String? {
    switch snapshot {
    case .connected(let ssid): ssid
    case .disconnected: lastSSID
    case .unidentified: nil
    }
  }

  public mutating func takeAutomaticTarget(for snapshot: WiFiSnapshot) -> String? {
    guard snapshot == .disconnected, let lastSSID, lastSSID != attemptedSSID else { return nil }
    markAttempt(for: lastSSID)
    return lastSSID
  }

  public mutating func markAttempt(for ssid: String) {
    attemptedSSID = ssid
    if ssid == lastSSID {
      didAttemptRecovery = true
      resetConnectivityFailures()
    }
  }
}
