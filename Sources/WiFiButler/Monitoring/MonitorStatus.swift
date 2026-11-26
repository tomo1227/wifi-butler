enum MonitorStatus: Equatable {
  case paused, disconnected, unidentified, noWiFiRoute, checking, online, unavailable
  case unexpectedResponse, portal, opening, browserFailed, sleeping, reconnecting

  var label: String {
    switch self {
    case .paused: "監視停止中"
    case .disconnected: "Wi-Fi 未接続"
    case .unidentified: "SSID を取得できません"
    case .noWiFiRoute: "Wi-Fi の通信経路を確認できません"
    case .checking: "インターネット接続を確認中"
    case .online: "インターネット接続済み"
    case .unavailable: "インターネットに接続できません"
    case .unexpectedResponse: "想定外の応答：認証ページかどうか未確認"
    case .portal: "認証ページの候補を検出"
    case .opening: "ブラウザで開いています"
    case .browserFailed: "選択したブラウザで開けませんでした"
    case .sleeping: "スリープ中"
    case .reconnecting: "再接続中"
    }
  }
}
