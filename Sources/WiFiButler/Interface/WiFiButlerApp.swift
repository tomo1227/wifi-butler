import SwiftUI

@main
struct WiFiButlerApp: App {
  @NSApplicationDelegateAdaptor(WorkspaceLifecycle.self) private var lifecycle
  @State private var speedTest = WiFiSpeedTestModel()

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

    Window("Wi-Fi の速度計測", id: "speed-test") {
      WiFiSpeedTestView(model: speedTest)
    }
    .defaultSize(width: 460, height: 290)
    .defaultLaunchBehavior(.suppressed)

    Window("DNS 設定", id: "dns-presets") {
      DNSPresetsView()
    }
    .defaultSize(width: 500, height: 360)
    .defaultLaunchBehavior(.suppressed)
  }
}
