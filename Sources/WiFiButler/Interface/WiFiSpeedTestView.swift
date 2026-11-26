import SwiftUI

struct WiFiSpeedTestView: View {
  let model: WiFiSpeedTestModel

  var body: some View {
    Form {
      Section("インターネット速度") {
        Text("Apple の計測サーバーと通信するため、データ通信量が発生します。表示されるのは Wi-Fi のリンク速度ではなく、インターネットへの実測値です。")
          .foregroundStyle(.secondary)

        Button("計測を開始", action: model.start)
          .disabled(model.state == .measuring)

        switch model.state {
        case .ready:
          EmptyView()
        case .measuring:
          ProgressView("速度を計測しています…")
        case .completed(let result):
          LabeledContent("下り（ダウンロード）") {
            Text("\(result.downloadMbps, format: .number.precision(.fractionLength(2))) Mbps")
          }
          LabeledContent("上り（アップロード）") {
            Text("\(result.uploadMbps, format: .number.precision(.fractionLength(2))) Mbps")
          }
        case .noWiFi:
          Text("Wi-Fi に接続してから、もう一度お試しください。")
        case .failed:
          Text("計測できませんでした。Wi-Fi でインターネットに接続できることを確認し、もう一度お試しください。")
        }
      }
    }
    .formStyle(.grouped)
    .frame(minWidth: 390, minHeight: 260)
  }
}
