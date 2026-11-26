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
    let image = NSImage(size: NSSize(width: 22, height: 18), flipped: true) { _ in
      NSColor.black.setFill()
      NSColor.black.setStroke()

      let bowTie = NSBezierPath()
      for side in [CGFloat(-1), 1] {
        bowTie.move(to: NSPoint(x: 8 + side * 2.5, y: 8))
        bowTie.line(to: NSPoint(x: 8 + side * 5.5, y: 5))
        bowTie.curve(
          to: NSPoint(x: 8 + side * 7, y: 5.75),
          controlPoint1: NSPoint(x: 8 + side * 6.25, y: 4.25),
          controlPoint2: NSPoint(x: 8 + side * 7, y: 4.75)
        )
        bowTie.line(to: NSPoint(x: 8 + side * 7, y: 12.25))
        bowTie.curve(
          to: NSPoint(x: 8 + side * 5.5, y: 13),
          controlPoint1: NSPoint(x: 8 + side * 7, y: 13.25),
          controlPoint2: NSPoint(x: 8 + side * 6.25, y: 13.75)
        )
        bowTie.line(to: NSPoint(x: 8 + side * 2.5, y: 10))
        bowTie.close()
      }
      bowTie.fill()
      NSBezierPath(roundedRect: NSRect(x: 6.5, y: 7, width: 3, height: 4), xRadius: 1, yRadius: 1)
        .fill()

      let mark = NSBezierPath()
      mark.lineWidth = 1.5
      mark.lineCapStyle = .round
      mark.lineJoinStyle = .round
      switch self {
      case .connected:
        mark.move(to: NSPoint(x: 17, y: 9.25))
        mark.line(to: NSPoint(x: 18.25, y: 10.5))
        mark.line(to: NSPoint(x: 20.5, y: 7.5))
      case .attention:
        mark.move(to: NSPoint(x: 18.75, y: 6.25))
        mark.line(to: NSPoint(x: 18.75, y: 9.25))
        NSBezierPath(ovalIn: NSRect(x: 18, y: 10.75, width: 1.5, height: 1.5)).fill()
      case .inactive:
        mark.move(to: NSPoint(x: 17.25, y: 9))
        mark.line(to: NSPoint(x: 20.25, y: 9))
      }
      mark.stroke()
      return true
    }
    image.isTemplate = true
    return image
  }
}
