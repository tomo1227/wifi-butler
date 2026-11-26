import AppKit
import XCTest

@testable import WiFiButler

final class MenuBarIconTests: XCTestCase {
  @MainActor
  func testSameWiFiGlyphIsVisibleWithEveryBadge() throws {
    let silhouettes = try [MonitorStatus.online, .portal, .disconnected].map { status in
      let image = ButlerMenuBarIcon.image(for: status)
      let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation)))
      let glyphWidth = bitmap.pixelsWide * 16 / 26
      return (0..<bitmap.pixelsHigh).flatMap { y in
        (0..<glyphWidth).map { x in
          (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5
        }
      }
    }
    XCTAssertTrue(silhouettes.allSatisfy { $0.contains(true) })
    XCTAssertEqual(Set(silhouettes).count, 1)
  }

  @MainActor
  func testOnlyOnlineArtworkHasGreenBadge() throws {
    let statuses: [MonitorStatus] = [
      .online, .portal, .unexpectedResponse, .browserFailed, .paused, .disconnected,
      .unidentified, .noWiFiRoute, .checking, .unavailable, .opening, .sleeping, .reconnecting,
    ]
    for status in statuses {
      let image = ButlerMenuBarIcon.image(for: status)
      let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation)))
      let hasGreenBadge = (0..<bitmap.pixelsHigh).contains { y in
        (0..<bitmap.pixelsWide).contains { x in
          guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
            return false
          }
          return color.alphaComponent > 0.9
            && color.greenComponent > color.redComponent + 0.2
            && color.greenComponent > color.blueComponent + 0.1
        }
      }
      XCTAssertEqual(hasGreenBadge, status == .online, status.label)
      XCTAssertEqual(image.isTemplate, status != .online, status.label)
    }
  }
}
