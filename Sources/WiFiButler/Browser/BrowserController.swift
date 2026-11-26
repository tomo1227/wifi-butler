import AppKit

@MainActor
struct BrowserController {
  func open(_ url: URL, in browser: Browser) async -> NSRunningApplication? {
    let workspace = NSWorkspace.shared
    let app: URL?
    if let bundleIdentifier = browser.bundleIdentifier {
      app = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier)
    } else {
      app = workspace.urlForApplication(toOpen: url)
    }
    guard let app else { return nil }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = false
    do {
      return try await workspace.open([url], withApplicationAt: app, configuration: configuration)
    } catch {
      // The caller reports a generic failure without persisting URLs or system error details.
      return nil
    }
  }
}
