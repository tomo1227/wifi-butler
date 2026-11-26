import ButlerCore
import SwiftUI

struct DNSPresetsView: View {
  @State private var manager = DNSConfigurationManager()

  var body: some View {
    Form {
      Section("Wi-Fi の DNS 設定") {
        LabeledContent("現在の設定", value: manager.currentConfiguration.title)

        Picker("適用する DNS", selection: $manager.selection) {
          ForEach(DNSPreset.allCases, id: \.self) { preset in
            Text(preset.title).tag(preset)
          }
        }

        if manager.selection == .automatic {
          LabeledContent("IPv4・IPv6", value: "ネットワークから自動取得")
        } else {
          LabeledContent("IPv4") {
            Text(verbatim: addresses(isIPv6: false))
              .textSelection(.enabled)
          }

          LabeledContent("IPv6") {
            Text(verbatim: addresses(isIPv6: true))
              .textSelection(.enabled)
          }
        }

        Button("適用") {
          manager.apply()
        }
        .disabled(manager.isApplying)

        if manager.isApplying {
          ProgressView("DNS 設定を適用しています…")
        }

        if let message = manager.message {
          Text(message)
            .foregroundStyle(manager.isError ? .red : .secondary)
        }
      }

      Section {
        Text(
          "この設定は現在の Wi-Fi サービス全体に適用されます。SSID ごとの設定ではありません。"
        )
        .foregroundStyle(.secondary)

        Text(
          "デフォルト（自動）を適用すると、手動指定の DNS サーバーだけを削除します。検索ドメインなどの設定は保持します。"
        )
        .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(minWidth: 460, minHeight: 340)
    .onAppear {
      manager.refresh()
    }
  }

  private func addresses(isIPv6: Bool) -> String {
    manager.selection.serverAddresses
      .filter { $0.contains(":") == isIPv6 }
      .joined(separator: ", ")
  }
}
