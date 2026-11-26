import Foundation

public enum ProbeResult: Equatable, Sendable {
  case expected
  case redirect(URL)
  case unexpected
  case failed
}
