import AppKit

@MainActor
enum ButlerMenuBarIcon {
  case connected, attention, inactive

  private static let connectedImage = Self.connected.makeImage()
  private static let attentionImage = Self.attention.makeImage()
  private static let inactiveImage = Self.inactive.makeImage()

  static func image(for status: MonitorStatus) -> NSImage {
    switch status {
    case .online: connectedImage
    case .portal, .unexpectedResponse, .browserFailed: attentionImage
    default: inactiveImage
    }
  }

  private func makeImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 26, height: 18), flipped: true) { _ in
      NSColor.black.setFill()
      NSColor.black.setStroke()
      Self.drawWiFi()

      let mark = NSBezierPath()
      mark.lineWidth = 1.5
      mark.lineCapStyle = .round
      mark.lineJoinStyle = .round
      switch self {
      case .connected:
        NSColor.labelColor.setFill()
        NSRect(x: 0, y: 0, width: 16, height: 18).fill(using: .sourceAtop)

        NSColor(srgbRed: 0.07, green: 0.49, blue: 0.25, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 16.5, y: 4.5, width: 9, height: 9)).fill()
        NSColor.white.setStroke()
        mark.move(to: NSPoint(x: 18.75, y: 9.25))
        mark.line(to: NSPoint(x: 20.25, y: 10.75))
        mark.line(to: NSPoint(x: 23.25, y: 7.5))
      case .attention:
        mark.move(to: NSPoint(x: 21, y: 6.25))
        mark.line(to: NSPoint(x: 21, y: 9.25))
        NSBezierPath(ovalIn: NSRect(x: 20.25, y: 10.75, width: 1.5, height: 1.5)).fill()
      case .inactive:
        mark.move(to: NSPoint(x: 19.5, y: 9))
        mark.line(to: NSPoint(x: 22.5, y: 9))
      }
      mark.stroke()
      return true
    }
    image.isTemplate = self != .connected
    return image
  }

  private static func drawWiFi() {
    let waves = NSBezierPath()
    waves.move(to: NSPoint(x: 1.5, y: 5.75))
    waves.curve(
      to: NSPoint(x: 14.5, y: 5.75),
      controlPoint1: NSPoint(x: 5, y: 2.5), controlPoint2: NSPoint(x: 11, y: 2.5))
    waves.move(to: NSPoint(x: 4, y: 8))
    waves.curve(
      to: NSPoint(x: 12, y: 8),
      controlPoint1: NSPoint(x: 6, y: 6), controlPoint2: NSPoint(x: 10, y: 6))
    waves.lineWidth = 1.5
    waves.lineCapStyle = .round
    waves.stroke()

    let router = NSBezierPath(
      roundedRect: NSRect(x: 3.25, y: 10.5, width: 9.5, height: 4.5),
      xRadius: 1.5, yRadius: 1.5)
    router.lineWidth = 1.5
    router.stroke()
    for x in [5.3, 9.3] {
      NSBezierPath(ovalIn: NSRect(x: x, y: 12.05, width: 1.4, height: 1.4)).fill()
    }
  }
}
