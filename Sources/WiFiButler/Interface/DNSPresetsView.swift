import ButlerCore
import SwiftUI

struct DNSPresetsView: View {
  @State private var selection: DNSPreset = .automatic

  var body: some View {
    Form {
      Section("Wi-Fi の DNS プリセット") {
        Picker("表示するプリセット", selection: $selection) {
          ForEach(DNSPreset.allCases, id: \.self) { preset in
            Text(label(for: preset)).tag(preset)
          }
        }
        if selection == .automatic {
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
      }

      Section {
        Text("この画面は参照用です。macOS の DNS 設定は変更されません。")
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(minWidth: 430, minHeight: 240)
  }

  private func addresses(isIPv6: Bool) -> String {
    selection.serverAddresses.filter { $0.contains(":") == isIPv6 }.joined(separator: ", ")
  }

  private func label(for preset: DNSPreset) -> LocalizedStringKey {
    switch preset {
    case .automatic: "デフォルト（自動）"
    case .cloudflare: "Cloudflare DNS"
    case .google: "Google Public DNS"
    }
  }
}
