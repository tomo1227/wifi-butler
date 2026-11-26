import Foundation

@MainActor
public struct PortalFlow {
  public init() {}

  public func run(
    retries: RetryManager,
    isCurrent: @MainActor () -> Bool,
    open: @MainActor () async -> Bool,
    press: (@MainActor () -> PortalButtonResult)?,
    verify: @MainActor () async -> Connectivity
  ) async -> PortalFlowResult {
    guard !Task.isCancelled, isCurrent() else { return .cancelled }
    let opened = await open()
    guard !Task.isCancelled, isCurrent() else { return .cancelled }
    guard opened else { return .browserFailed }

    do {
      if let press {
        let result: PortalButtonResult? = try await retries.run {
          guard isCurrent() else { return .cancelled }
          let result = press()
          return result == .notReady ? nil : result
        }
        switch result {
        case .pressed: break
        case .cancelled: return .cancelled
        default: return .manualRequired(result ?? .notReady)
        }
      }

      return try await verifyConnection(retries: retries, isCurrent: isCurrent, verify: verify)
    } catch {
      return .cancelled
    }
  }

  private func verifyConnection(
    retries: RetryManager,
    isCurrent: @MainActor () -> Bool,
    verify: @MainActor () async -> Connectivity
  ) async throws -> PortalFlowResult {
    let result: PortalFlowResult? = try await retries.run {
      guard isCurrent() else { return .cancelled }
      let connectivity = await verify()
      guard !Task.isCancelled, isCurrent() else { return .cancelled }
      return connectivity == .online ? .verified : nil
    }
    return result ?? .notVerified
  }
}
