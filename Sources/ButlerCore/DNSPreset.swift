public enum DNSPreset: CaseIterable, Sendable {
  case automatic
  case cloudflare
  case google

  public var serverAddresses: [String] {
    switch self {
    case .automatic: []
    case .cloudflare: ["1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001"]
    case .google: ["8.8.8.8", "8.8.4.4", "2001:4860:4860::8888", "2001:4860:4860::8844"]
    }
  }

  public init?(serverAddresses: [String]) {
    guard let preset = Self.allCases.first(where: { $0.serverAddresses == serverAddresses })
    else { return nil }
    self = preset
  }
}
