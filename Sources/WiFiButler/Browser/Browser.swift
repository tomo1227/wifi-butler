enum Browser: String, CaseIterable, Codable, Identifiable {
  case dia
  case safari

  var id: Self { self }

  var name: String {
    switch self {
    case .dia: "Dia"
    case .safari: "Safari"
    }
  }

  var bundleIdentifier: String {
    switch self {
    case .dia: "company.thebrowser.dia"
    case .safari: "com.apple.Safari"
    }
  }
}
