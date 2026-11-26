import ButlerCore
import CoreWLAN
import Foundation
import Observation
import Security
import SystemConfiguration

@MainActor
@Observable
final class DNSConfigurationManager {
  enum CurrentConfiguration: Equatable {
    case automatic
    case preset(DNSPreset)
    case custom

    var title: String {
      switch self {
      case .automatic:
        "デフォルト（自動）"
      case .preset(let preset):
        preset.title
      case .custom:
        "カスタム"
      }
    }
  }

  private(set) var currentConfiguration: CurrentConfiguration = .automatic
  private(set) var isApplying = false
  private(set) var message: String?
  private(set) var isError = false

  var selection: DNSPreset = .automatic

  func refresh() {
    do {
      let (preferences, authorization) = try createPreferences()
      defer { AuthorizationFree(authorization, []) }

      let service = try currentWiFiService(preferences: preferences)
      let dns = try dnsProtocol(for: service)

      guard let configuration = SCNetworkProtocolGetConfiguration(dns) as? [String: Any],
        let addresses = configuration[kSCPropNetDNSServerAddresses as String] as? [String],
        !addresses.isEmpty
      else {
        currentConfiguration = .automatic
        selection = .automatic
        message = nil
        isError = false
        return
      }

      if let preset = DNSPreset(serverAddresses: addresses), preset != .automatic {
        currentConfiguration = .preset(preset)
        selection = preset
      } else {
        currentConfiguration = .custom
      }

      message = nil
      isError = false
    } catch {
      message = error.localizedDescription
      isError = true
    }
  }

  func apply() {
    guard !isApplying else { return }

    isApplying = true
    message = nil
    isError = false

    defer { isApplying = false }

    do {
      let (preferences, authorization) = try createPreferences()
      defer { AuthorizationFree(authorization, []) }

      let service = try currentWiFiService(preferences: preferences)
      let dns = try dnsProtocol(for: service)

      var configuration =
        SCNetworkProtocolGetConfiguration(dns) as? [String: Any] ?? [:]

      if selection == .automatic {
        configuration.removeValue(forKey: kSCPropNetDNSServerAddresses as String)
      } else {
        configuration[kSCPropNetDNSServerAddresses as String] = selection.serverAddresses
      }

      guard SCNetworkProtocolSetConfiguration(dns, configuration as CFDictionary) else {
        throw DNSConfigurationError.configurationFailed
      }

      guard SCPreferencesCommitChanges(preferences) else {
        throw DNSConfigurationError.commitFailed
      }

      guard SCPreferencesApplyChanges(preferences) else {
        throw DNSConfigurationError.applyFailed
      }

      let expected: CurrentConfiguration =
        selection == .automatic
        ? .automatic
        : .preset(selection)

      let actual = try readCurrentConfiguration()

      guard actual == expected else {
        throw DNSConfigurationError.applyVerificationFailed
      }

      currentConfiguration = actual
      message = "\(selection.title) を適用しました。"
    } catch {
      message = error.localizedDescription
      isError = true
      refresh()
      isError = true
      message = error.localizedDescription
    }
  }

  private func readCurrentConfiguration() throws -> CurrentConfiguration {
    let (preferences, authorization) = try createPreferences()
    defer { AuthorizationFree(authorization, []) }

    let service = try currentWiFiService(preferences: preferences)
    let dns = try dnsProtocol(for: service)

    guard let configuration = SCNetworkProtocolGetConfiguration(dns) as? [String: Any],
      let addresses = configuration[kSCPropNetDNSServerAddresses as String] as? [String],
      !addresses.isEmpty
    else {
      return .automatic
    }

    if let preset = DNSPreset(serverAddresses: addresses), preset != .automatic {
      return .preset(preset)
    }

    return .custom
  }

  private func currentWiFiService(
    preferences: SCPreferences
  ) throws -> SCNetworkService {
    guard let interface = CWWiFiClient.shared().interface(),
      let interfaceName = interface.interfaceName,
      interface.ssid() != nil
    else {
      throw DNSConfigurationError.noActiveWiFi
    }

    guard let currentSet = SCNetworkSetCopyCurrent(preferences),
      let services = SCNetworkSetCopyServices(currentSet) as? [SCNetworkService]
    else {
      throw DNSConfigurationError.networkServicesUnavailable
    }

    let matchingServices = services.filter { service in
      guard let networkInterface = SCNetworkServiceGetInterface(service),
        SCNetworkInterfaceGetInterfaceType(networkInterface)
          == kSCNetworkInterfaceTypeIEEE80211,
        let bsdName = SCNetworkInterfaceGetBSDName(networkInterface)
      else {
        return false
      }

      return (bsdName as String) == interfaceName
    }

    guard matchingServices.count == 1, let service = matchingServices.first else {
      throw DNSConfigurationError.wifiServiceNotUnique
    }

    return service
  }

  private func dnsProtocol(for service: SCNetworkService) throws -> SCNetworkProtocol {
    guard let dns = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeDNS) else {
      throw DNSConfigurationError.dnsProtocolUnavailable
    }

    return dns
  }

  private func createPreferences() throws -> (SCPreferences, AuthorizationRef) {
    var authorization: AuthorizationRef?

    let status = AuthorizationCreate(
      nil,
      nil,
      [.interactionAllowed, .extendRights],
      &authorization
    )

    guard status == errAuthorizationSuccess, let authorization else {
      throw DNSConfigurationError.authorizationFailed
    }

    guard
      let preferences = SCPreferencesCreateWithAuthorization(
        nil,
        "WiFiButler" as CFString,
        nil,
        authorization
      )
    else {
      AuthorizationFree(authorization, [])
      throw DNSConfigurationError.preferencesUnavailable
    }

    return (preferences, authorization)
  }
}

private enum DNSConfigurationError: LocalizedError {
  case authorizationFailed
  case preferencesUnavailable
  case noActiveWiFi
  case networkServicesUnavailable
  case wifiServiceNotUnique
  case dnsProtocolUnavailable
  case configurationFailed
  case commitFailed
  case applyFailed
  case applyVerificationFailed

  var errorDescription: String? {
    switch self {
    case .authorizationFailed:
      "認証を取得できませんでした。"
    case .preferencesUnavailable:
      "ネットワーク設定を読み込めませんでした。"
    case .noActiveWiFi:
      "接続中の Wi-Fi が見つかりません。"
    case .networkServicesUnavailable:
      "ネットワークサービスを取得できませんでした。"
    case .wifiServiceNotUnique:
      "対象の Wi-Fi サービスを一意に特定できません。設定は変更していません。"
    case .dnsProtocolUnavailable:
      "Wi-Fi の DNS 設定を取得できませんでした。"
    case .configurationFailed:
      "DNS 設定を変更できませんでした。"
    case .commitFailed:
      "DNS 設定を保存できませんでした。認証がキャンセルされた可能性があります。"
    case .applyFailed:
      "DNS 設定を保存しましたが、システムへの反映に失敗しました。"
    case .applyVerificationFailed:
      "適用後の DNS 設定が選択内容と一致しません。"
    }
  }
}
