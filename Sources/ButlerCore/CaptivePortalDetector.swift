import Foundation

public enum CaptivePortalDetector {
  public static func classify(http: ProbeResult, https: ProbeResult) -> Connectivity {
    if https == .expected { return .online }
    if case .redirect(let url) = http { return .portal(url) }
    if http == .unexpected || https == .unexpected { return .unexpectedResponse }
    return .unavailable
  }

  public static func response(status: Int, location: String?, body: Data, endpoint: URL)
    -> ProbeResult
  {
    if status == 200,
      String(decoding: body, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        == "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"
    {
      return .expected
    }

    guard [301, 302, 303, 307, 308, 511].contains(status),
      let location,
      let url = URL(string: location, relativeTo: endpoint)?.absoluteURL,
      isWebURL(url),
      url.host()?.caseInsensitiveCompare(endpoint.host() ?? "") != .orderedSame
    else { return .unexpected }
    return .redirect(url)
  }

  public static func isWebURL(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
      let host = url.host(), !host.isEmpty
    else { return false }
    return url.user() == nil && url.password() == nil
  }
}
