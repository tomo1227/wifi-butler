public enum PortalFlowResult: Equatable, Sendable {
  case verified
  case notVerified
  case browserFailed
  case manualRequired(PortalButtonResult)
  case cancelled
}
