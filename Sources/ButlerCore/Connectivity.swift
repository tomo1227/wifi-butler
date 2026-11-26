import Foundation

public enum Connectivity: Equatable, Sendable {
  case online
  case unavailable
  case unexpectedResponse
  case portal(URL)
}
