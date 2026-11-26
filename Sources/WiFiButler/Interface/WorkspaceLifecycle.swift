import AppKit

@MainActor
final class WorkspaceLifecycle: NSObject, NSApplicationDelegate {
  let model = MonitorModel()

  func applicationDidFinishLaunching(_ notification: Notification) {
    let center = NSWorkspace.shared.notificationCenter
    center.addObserver(
      self, selector: #selector(sleep), name: NSWorkspace.willSleepNotification, object: nil)
    center.addObserver(
      self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
    model.startObservingWiFi()
  }

  @objc private func sleep() {
    model.setSleeping(true)
  }

  @objc private func wake() {
    model.setSleeping(false)
  }
}
