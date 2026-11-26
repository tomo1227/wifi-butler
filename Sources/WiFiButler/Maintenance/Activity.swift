import Foundation

struct Activity: Identifiable, Codable {
  enum Kind: String, Codable {
    case portalDetected, browserFailed, verified

    var label: String {
      switch self {
      case .portalDetected: "認証ページの候補を検出"
      case .browserFailed: "ブラウザで開けませんでした"
      case .verified: "手動操作後のインターネット接続を確認"
      }
    }
  }

  var id = UUID()
  var date = Date.now
  var kind: Kind
}
