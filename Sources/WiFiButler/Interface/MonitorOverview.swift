import ButlerCore
import SwiftUI

struct MonitorOverview: View {
  @Bindable var model: MonitorModel

  var body: some View {
    Form {
      Section("接続状況") {
        LabeledContent("現在の SSID") {
          if case .connected(let ssid) = model.snapshot {
            Text(verbatim: ssid)
          } else {
            Text("—")
          }
        }
        LabeledContent("通信状態", value: model.status.label)
        Toggle("Wi-Fi が切断されたら自動で再接続", isOn: $model.autoReconnect)
        Button("Wi-Fi に再接続", action: model.reconnect)
          .disabled(!model.canReconnect)
        if model.reconnectFailed {
          Text("再接続できませんでした。macOS の Wi-Fi メニューで接続してください。")
        }
        dateRow("最後の認証確認", date: model.lastVerified)
        dateRow("次回の確認予定", date: model.nextCheck)
        if model.status == .unidentified {
          Text("SSID を読み取るために位置情報へのアクセスが必要です。位置座標は取得しません。")
          Button("位置情報の許可をリクエスト", action: model.requestLocationPermission)
        }
      }

      Section("手動認証") {
        Picker("ブラウザ", selection: $model.browser) {
          ForEach(Browser.allCases) { browser in
            Text(verbatim: browser.name).tag(browser)
          }
        }
        if let portal = model.portal, let host = portal.host() {
          LabeledContent("候補のホスト", value: host)
          Text("接続先が Wi-Fi 提供者のページであることを確認し、利用規約はご自身で確認してください。")
          Button("選択したブラウザで開く", action: model.openDetectedPortal)
            .disabled(model.status == .opening)
        } else {
          Text("認証 URL が表示されない場合は、macOS の Wi-Fi ログイン画面で手動認証してください。")
        }
      }

      Section {
        DisclosureGroup("監視対象の Wi-Fi") {
          ForEach(SupportedWiFi.ssids.sorted(), id: \.self) { ssid in
            Text(verbatim: ssid)
          }
        }
      }

      Section("履歴（過去7日間）") {
        if model.activities.isEmpty { Text("履歴はありません") }
        ForEach(model.activities) { activity in
          LabeledContent {
            Text(activity.date, format: .dateTime.month().day().hour().minute())
          } label: {
            Text(verbatim: activity.kind.label)
          }
        }
      }
    }
    .formStyle(.grouped)
    .frame(minWidth: 390, minHeight: 350)
  }

  private func dateRow(_ title: LocalizedStringKey, date: Date?) -> some View {
    LabeledContent {
      if let date {
        Text(date, format: .dateTime.month().day().hour().minute().second())
      } else {
        Text("—")
      }
    } label: {
      Text(title)
    }
  }
}
