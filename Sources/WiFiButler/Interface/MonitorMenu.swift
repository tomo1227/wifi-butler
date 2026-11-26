import SwiftUI

struct MonitorMenu: View {
  let model: MonitorModel
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Text(verbatim: model.status.label)

    if case .connected(let name) = model.snapshot {
      Text(verbatim: name)
    }

    if model.reconnectFailed {
      Text("再接続できませんでした。macOS の Wi-Fi メニューで接続してください。")
    }

    Divider()

    if model.isMonitoring {
      Button("今すぐ確認", action: model.refresh)
        .disabled(model.status == .reconnecting)

      Button("再接続", action: model.reconnect)
        .disabled(!model.canReconnect)

      if let host = model.portal?.host() {
        Text(verbatim: host)
        Button("認証ページをブラウザで開く", action: model.openDetectedPortal)
          .disabled(model.status == .opening)
      }

      Button("監視を停止") {
        model.setMonitoring(false)
      }
    } else {
      Button("監視を開始") {
        model.setMonitoring(true)
      }
    }

    Button("状況・履歴を表示") {
      openWindow(id: "overview")
      NSApplication.shared.activate()
    }

    Button("通信速度計測", action: openSpeedTest)

    Button("DNS 設定") {
      openWindow(id: "dns-presets")
      NSApplication.shared.activate()
    }

    Divider()

    Button("WiFi Butler を終了") {
      NSApplication.shared.terminate(nil)
    }
    .keyboardShortcut("q")
  }

  private func openSpeedTest() {
    openWindow(id: "speed-test")
    NSApplication.shared.activate()
  }
}
