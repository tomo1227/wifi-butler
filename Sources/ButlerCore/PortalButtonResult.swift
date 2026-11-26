public enum PortalButtonResult: Equatable, Sendable {
  case pressed
  case permissionRequired
  case notReady
  case ambiguous
  case pressFailed
  case cancelled
}
