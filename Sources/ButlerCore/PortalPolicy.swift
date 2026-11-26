import Foundation

public struct PortalPolicy: Equatable, Sendable {
  public let ssid: String
  public let page: URL
  public let button: String

  public init?(ssid: String, page: String, button: String) {
    guard !ssid.isEmpty, !button.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let url = URL(string: page, encodingInvalidCharacters: false),
      CaptivePortalDetector.isWebURL(url), url.scheme == "https",
      url.query() == nil, url.fragment() == nil
    else { return nil }
    self.ssid = ssid
    self.page = url
    self.button = button
  }

  public func permits(_ url: URL, on network: WiFiSnapshot) -> Bool {
    network == .connected(ssid) && url.absoluteString == page.absoluteString
  }
}
