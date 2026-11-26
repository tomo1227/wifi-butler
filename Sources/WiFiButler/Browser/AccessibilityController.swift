import AppKit
import ApplicationServices
import ButlerCore

@MainActor
struct AccessibilityController {
  func requestPermission() {
    AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
  }

  var isTrusted: Bool { AXIsProcessTrusted() }

  func press(
    in app: NSRunningApplication, policy: PortalPolicy, isCurrent: () -> Bool
  ) -> PortalButtonResult {
    guard isTrusted else { return .permissionRequired }
    guard isForeground(app) else { return .notReady }
    let application = AXUIElementCreateApplication(app.processIdentifier)
    AXUIElementSetMessagingTimeout(application, 0.15)
    guard let window = element(application, kAXFocusedWindowAttribute) else { return .notReady }
    let deadline = ContinuousClock.now + .milliseconds(700)
    guard let areas = matches(in: window, role: "AXWebArea", deadline: deadline),
      areas.count == 1, let area = areas.first, isApprovedPage(area, policy: policy)
    else { return .notReady }
    guard let buttons = matches(in: area, role: kAXButtonRole, deadline: deadline) else {
      return .notReady
    }
    let candidates = buttons.filter { string($0, kAXTitleAttribute) == policy.button }
    guard candidates.count <= 1 else { return .ambiguous }
    guard let button = candidates.first, (attribute(button, kAXEnabledAttribute) as? Bool) == true
    else { return .notReady }
    var actions: CFArray?
    guard AXUIElementCopyActionNames(button, &actions) == .success,
      (actions as? [String])?.contains(kAXPressAction) == true,
      isApprovedPage(area, policy: policy),
      let focused = element(application, kAXFocusedWindowAttribute), CFEqual(window, focused),
      isForeground(app), isCurrent()
    else { return .notReady }
    return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
      ? .pressed : .pressFailed
  }

  private func isForeground(_ app: NSRunningApplication) -> Bool {
    NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
  }

  private func isApprovedPage(_ area: AXUIElement, policy: PortalPolicy) -> Bool {
    (attribute(area, kAXURLAttribute) as? URL)?.absoluteString == policy.page.absoluteString
  }

  private func matches(in root: AXUIElement, role: String, deadline: ContinuousClock.Instant)
    -> [AXUIElement]?
  {
    var pending = [root]
    var found: [AXUIElement] = []
    var visited = 0
    while let node = pending.popLast() {
      visited += 1
      guard visited <= 160, ContinuousClock.now < deadline,
        let nodeRole = string(node, kAXRoleAttribute)
      else { return nil }
      if nodeRole == role {
        found.append(node)
        if role == "AXWebArea" { continue }
      }
      // Do not operate on controls in third-party frames.
      if nodeRole == "AXWebArea", !CFEqual(root, node) { continue }
      if let children = attribute(node, kAXChildrenAttribute) as? [AXUIElement] {
        guard children.count + pending.count <= 160 else { return nil }
        pending.append(contentsOf: children)
      }
    }
    return found
  }

  private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success
      ? value : nil
  }

  private func string(_ element: AXUIElement, _ name: String) -> String? {
    attribute(element, name) as? String
  }

  private func element(_ source: AXUIElement, _ name: String) -> AXUIElement? {
    guard let value = attribute(source, name), CFGetTypeID(value) == AXUIElementGetTypeID()
    else { return nil }
    return (value as! AXUIElement)
  }
}
