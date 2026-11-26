public struct RetryManager: Sendable {
  public let attempts: Int
  public let interval: Duration

  public init(retries: Int, intervalSeconds: Int) {
    attempts = min(max(retries, 0), 5) + 1
    interval = .seconds(min(max(intervalSeconds, 2), 30))
  }

  @MainActor
  public func run<Value>(
    _ operation: @MainActor () async -> Value?,
    wait: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
  ) async throws -> Value? {
    for attempt in 0..<attempts {
      try Task.checkCancellation()
      if attempt > 0 { try await wait(interval) }
      try Task.checkCancellation()
      if let value = await operation() { return value }
    }
    return nil
  }
}
