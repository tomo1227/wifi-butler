import ButlerCore
import XCTest

final class CaptivePortalTests: XCTestCase {
  private let endpoint = URL(string: "http://captive.apple.com/hotspot-detect.html")!
  private let portal = URL(string: "https://example.test/terms")!

  func testWiFiAllowlistRequiresExactKnownSSID() {
    let allowed: Set<String> = ["DOUTOR_FREE_Wi-Fi"]
    XCTAssertTrue(WiFiSnapshot.connected("DOUTOR_FREE_Wi-Fi").isAllowed(by: allowed))
    XCTAssertFalse(WiFiSnapshot.connected("doutor_free_wi-fi").isAllowed(by: allowed))
    XCTAssertFalse(WiFiSnapshot.disconnected.isAllowed(by: allowed))
    XCTAssertFalse(WiFiSnapshot.unidentified.isAllowed(by: allowed))
  }

  func testOnlyExpectedHTTPSProvesConnectivity() {
    XCTAssertEqual(
      CaptivePortalDetector.classify(http: .redirect(portal), https: .expected), .online)
    XCTAssertEqual(CaptivePortalDetector.classify(http: .expected, https: .failed), .unavailable)
  }

  func testCaptivePortalAndOutageAreDistinct() {
    XCTAssertEqual(
      CaptivePortalDetector.classify(http: .redirect(portal), https: .failed), .portal(portal))
    XCTAssertEqual(CaptivePortalDetector.classify(http: .failed, https: .failed), .unavailable)
    XCTAssertEqual(
      CaptivePortalDetector.classify(http: .unexpected, https: .failed), .unexpectedResponse
    )
  }

  func testManualPortalRequiresTwoMatchingConsecutiveObservations() {
    let changed = URL(string: "https://different.test/terms")!
    var evidence = PortalEvidence()
    evidence.observe(.portal(portal))
    XCTAssertNil(evidence.confirmed)
    evidence.observe(.portal(changed))
    XCTAssertNil(evidence.confirmed)
    evidence.observe(.unavailable)
    evidence.observe(.portal(changed))
    XCTAssertNil(evidence.confirmed)
    evidence.observe(.portal(changed))
    XCTAssertEqual(evidence.confirmed, changed)
    evidence.observe(.online)
    XCTAssertNil(evidence.confirmed)
  }

  func testExpectedResponseRequiresExactBodyAndStatus() {
    let body = Data("<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>\n".utf8)
    XCTAssertEqual(
      CaptivePortalDetector.response(status: 200, location: nil, body: body, endpoint: endpoint),
      .expected)
    XCTAssertEqual(
      CaptivePortalDetector.response(status: 503, location: nil, body: body, endpoint: endpoint),
      .unexpected)
    XCTAssertEqual(
      CaptivePortalDetector.response(
        status: 200, location: nil, body: Data("Success".utf8), endpoint: endpoint), .unexpected)
  }

  func testOnlySafeCrossHostRedirectsAreExposed() {
    for location in ["/terms", "javascript:alert(1)", "https://u:p@example.test/terms"] {
      XCTAssertEqual(
        CaptivePortalDetector.response(
          status: 302, location: location, body: Data(), endpoint: endpoint),
        .unexpected
      )
    }
    XCTAssertEqual(
      CaptivePortalDetector.response(
        status: 511, location: portal.absoluteString, body: Data(), endpoint: endpoint),
      .redirect(portal)
    )
  }
}
