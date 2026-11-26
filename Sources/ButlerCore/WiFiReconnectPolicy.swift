public struct WiFiReconnectPolicy: Sendable {
  private var lastSSID: String?
  private var attemptedSSID: String?

  public init() {}

  public mutating func observe(_ snapshot: WiFiSnapshot) {
    if case .connected(let ssid) = snapshot {
      lastSSID = SupportedWiFi.ssids.contains(ssid) ? ssid : nil
      attemptedSSID = nil
    }
  }

  public func manualTarget(for snapshot: WiFiSnapshot) -> String? {
    switch snapshot {
    case .connected(let ssid): SupportedWiFi.ssids.contains(ssid) ? ssid : nil
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
  }
}
