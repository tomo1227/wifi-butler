import ButlerCore
import XCTest

final class DNSPresetTests: XCTestCase {
  func testCloudflareProvidesBothAddressFamilies() {
    XCTAssertEqual(
      DNSPreset.cloudflare.serverAddresses,
      ["1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001"])
  }

  func testGoogleProvidesBothAddressFamilies() {
    XCTAssertEqual(
      DNSPreset.google.serverAddresses,
      ["8.8.8.8", "8.8.4.4", "2001:4860:4860::8888", "2001:4860:4860::8844"])
  }

  func testPresetDetectionDoesNotMistakeManualDNSForAutomatic() {
    XCTAssertTrue(DNSPreset.automatic.serverAddresses.isEmpty)
    for preset in DNSPreset.allCases {
      XCTAssertEqual(DNSPreset(serverAddresses: preset.serverAddresses), preset)
    }
    XCTAssertNil(DNSPreset(serverAddresses: ["1.1.1.1"]))
    XCTAssertNil(DNSPreset(serverAddresses: ["192.0.2.53"]))
  }
}
