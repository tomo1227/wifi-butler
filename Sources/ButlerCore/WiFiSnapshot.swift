public enum WiFiSnapshot: Equatable, Sendable {
  case disconnected
  case unidentified
  case connected(String)

  public func isAllowed(by ssids: Set<String>) -> Bool {
    guard case .connected(let ssid) = self else { return false }
    return ssids.contains(ssid)
  }
}
