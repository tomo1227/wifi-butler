import SwiftUI

@main
struct WiFiButlerApp: App {
  @NSApplicationDelegateAdaptor(WorkspaceLifecycle.self) private var lifecycle

  var body: some Scene {
    MenuBarExtra {
      MonitorMenu(model: lifecycle.model)
    } label: {
      Label {
        Text("WiFi Butler: \(lifecycle.model.status.label)")
      } icon: {
        Image(nsImage: ButlerMenuBarIcon.image(for: lifecycle.model.status))
      }
      .labelStyle(.iconOnly)
    }

    Window("WiFi Butler", id: "overview") {
      MonitorOverview(model: lifecycle.model)
    }
    .defaultSize(width: 490, height: 530)
    .defaultLaunchBehavior(.suppressed)
  }
}
