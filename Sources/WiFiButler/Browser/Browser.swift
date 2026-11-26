enum Browser: String, CaseIterable, Codable, Identifiable {
  case systemDefault
  case dia
  case safari
  case chrome
  case firefox
  case edge
  case brave
  case arc
  case opera
  case vivaldi

  var id: Self { self }

  var name: String {
    switch self {
    case .systemDefault: "macOS のデフォルト"
    case .dia: "Dia"
    case .safari: "Safari"
    case .chrome: "Google Chrome"
    case .firefox: "Firefox"
    case .edge: "Microsoft Edge"
    case .brave: "Brave"
    case .arc: "Arc"
    case .opera: "Opera"
    case .vivaldi: "Vivaldi"
    }
  }

  var bundleIdentifier: String? {
    switch self {
    case .systemDefault: nil
    case .dia: "company.thebrowser.dia"
    case .safari: "com.apple.Safari"
    case .chrome: "com.google.Chrome"
    case .firefox: "org.mozilla.firefox"
    case .edge: "com.microsoft.edgemac"
    case .brave: "com.brave.Browser"
    case .arc: "company.thebrowser.Browser"
    case .opera: "com.operasoftware.Opera"
    case .vivaldi: "com.vivaldi.Vivaldi"
    }
  }
}
