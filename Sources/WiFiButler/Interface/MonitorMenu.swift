import SwiftUI

struct MonitorMenu: View {
  let model: MonitorModel
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Text(verbatim: model.status.label)
    if case .connected(let name) = model.snapshot {
      Text(verbatim: name)
    }
    Text("自動認証：無効（手動確認のみ）")
    Divider()
    if model.isMonitoring {
      Button("今すぐ確認", action: model.refresh)
      Button("監視を停止") { model.setMonitoring(false) }
    } else {
      Button("監視を開始") { model.setMonitoring(true) }
    }
    Button("状況・履歴を表示") {
      openWindow(id: "overview")
      NSApplication.shared.activate()
    }
    Divider()
    Button("WiFi Butler を終了") { NSApplication.shared.terminate(nil) }
      .keyboardShortcut("q")
  }
}
