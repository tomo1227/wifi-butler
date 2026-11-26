import ButlerCore
import Foundation

final class ConnectivityMonitor: NSObject, URLSessionTaskDelegate, Sendable {
  private static let https = URL(string: "https://captive.apple.com/hotspot-detect.html")!
  private static let http = URL(string: "http://captive.apple.com/hotspot-detect.html")!
  private let session: URLSession

  override init() {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.urlCache = nil
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.urlCredentialStorage = nil
    configuration.timeoutIntervalForRequest = 5
    configuration.timeoutIntervalForResource = 7
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    session = URLSession(configuration: configuration)
    super.init()
  }

  func check(allowsHTTP: @MainActor @Sendable () -> Bool) async -> Connectivity {
    let secure = await probe(Self.https)
    guard secure != .expected, !Task.isCancelled else {
      return Task.isCancelled ? .unavailable : .online
    }
    guard await allowsHTTP(), !Task.isCancelled else { return .unavailable }
    return CaptivePortalDetector.classify(http: await probe(Self.http), https: secure)
  }

  private func probe(_ endpoint: URL) async -> ProbeResult {
    do {
      let (bytes, response) = try await session.bytes(from: endpoint, delegate: self)
      guard let http = response as? HTTPURLResponse else { return .unexpected }
      var body = Data()
      if http.statusCode == 200 {
        for try await byte in bytes {
          guard body.count < 1024 else { return .unexpected }
          body.append(byte)
        }
      }
      return CaptivePortalDetector.response(
        status: http.statusCode, location: http.value(forHTTPHeaderField: "Location"),
        body: body, endpoint: endpoint
      )
    } catch {
      return .failed
    }
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest
  ) async -> URLRequest? {
    nil
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge
  ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
    if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
      return (.performDefaultHandling, nil)
    }
    return (.cancelAuthenticationChallenge, nil)
  }
}
