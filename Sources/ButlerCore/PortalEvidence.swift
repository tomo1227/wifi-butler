import Foundation

public struct PortalEvidence: Sendable {
  private var previous: URL?
  public private(set) var confirmed: URL?

  public init() {}

  public mutating func observe(_ result: Connectivity) {
    guard case .portal(let url) = result else {
      self = Self()
      return
    }
    confirmed = url == previous ? url : nil
    previous = url
  }
}
