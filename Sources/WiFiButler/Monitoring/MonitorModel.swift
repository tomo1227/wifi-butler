import AppKit
import ButlerCore
import Observation

@MainActor
@Observable
final class MonitorModel {
  static let target = "DOUTOR_FREE_Wi-Fi"

  private let wifi = WiFiMonitor()
  private let connectivity = ConnectivityMonitor()
  private let controller = BrowserController()
  private let logger = EventLogger()
  private var checking: Task<Void, Never>?
  private var generation = 0
  private var sleeping = false
  private var opening = false
  private var openedPortal = false
  private var evidence = PortalEvidence()
  private var attempts = 0

  private(set) var isMonitoring = false
  private(set) var status = MonitorStatus.paused
  private(set) var snapshot = WiFiSnapshot.disconnected
  private(set) var nextCheck: Date?
  private(set) var lastVerified: Date?
  private(set) var activities: [Activity] = []
  private(set) var portal: URL?
  var browser = Browser.dia

  init() {
    activities = logger.recent()
    lastVerified = activities.first { $0.kind == .verified }?.date
    wifi.start { [weak self] in self?.refreshAfterPathChange() }
  }

  func setMonitoring(_ enabled: Bool) {
    isMonitoring = enabled
    if enabled { wifi.requestLocationPermission() }
    resetCandidate()
    openedPortal = false
    refresh()
  }

  func requestLocationPermission() {
    wifi.requestLocationPermission()
  }

  func setSleeping(_ value: Bool) {
    sleeping = value
    resetCandidate()
    openedPortal = false
    refresh()
  }

  func refresh() {
    generation += 1
    checking?.cancel()
    nextCheck = nil
    portal = nil
    guard isMonitoring else {
      status = .paused
      snapshot = .disconnected
      return
    }
    guard !sleeping else {
      status = .sleeping
      return
    }
    let currentGeneration = generation
    checking = Task { [weak self] in await self?.check(generation: currentGeneration) }
  }

  func openPortal(_ url: URL) async {
    guard !opening, status == .portal || status == .browserFailed, url == portal,
      isMonitoring, !sleeping, isCurrentNetwork
    else { return }
    generation += 1
    checking?.cancel()
    nextCheck = nil
    let currentGeneration = generation
    opening = true
    defer { opening = false }
    status = .opening
    let app = await controller.open(url, in: browser)
    guard generation == currentGeneration else { return }
    guard isCurrentNetwork else { return refresh() }
    if app == nil {
      status = .browserFailed
      activities = logger.recent(adding: .browserFailed)
    } else {
      openedPortal = true
      attempts = 0
      status = .portal
    }
    schedule(after: app == nil ? 30 : 5, generation: currentGeneration)
  }

  private var isCurrentNetwork: Bool {
    wifi.snapshot().isAllowed(by: [Self.target]) && wifi.hasWiFiRoute
  }

  private func refreshAfterPathChange() {
    guard isMonitoring, !sleeping else { return }
    if snapshot != wifi.snapshot() || (!wifi.hasWiFiRoute && status != .noWiFiRoute) {
      resetCandidate()
      openedPortal = false
      refresh()
    } else if status == .noWiFiRoute && wifi.hasWiFiRoute {
      refresh()
    }
  }

  private func check(generation currentGeneration: Int) async {
    let current = wifi.snapshot()
    if current != snapshot {
      resetCandidate()
      openedPortal = false
    }
    snapshot = current
    if let blocked = blockedStatus(current) {
      status = blocked
      schedule(after: 30, generation: currentGeneration)
      return
    }
    if status != .portal && status != .browserFailed { status = .checking }
    let result = await connectivity.check { [weak self] in
      guard let self else { return false }
      return self.generation == currentGeneration && self.isCurrentNetwork
    }
    guard !Task.isCancelled, generation == currentGeneration else { return }
    guard isCurrentNetwork else { return refresh() }
    schedule(after: record(result), generation: currentGeneration)
  }

  private func blockedStatus(_ current: WiFiSnapshot) -> MonitorStatus? {
    switch current {
    case .disconnected: .disconnected
    case .unidentified: .unidentified
    case .connected(let name) where name != Self.target: .excluded
    case .connected: wifi.hasWiFiRoute ? nil : .noWiFiRoute
    }
  }

  private func record(_ result: Connectivity) -> Int {
    evidence.observe(result)
    switch result {
    case .online:
      if openedPortal {
        lastVerified = .now
        activities = logger.recent(adding: .verified)
      }
      openedPortal = false
      resetCandidate()
      status = .online
    case .unavailable:
      resetCandidate()
      status = .unavailable
    case .unexpectedResponse:
      resetCandidate()
      status = .unexpectedResponse
    case .portal:
      guard let url = evidence.confirmed else {
        portal = nil
        status = .checking
        return 3
      }
      if portal != url { activities = logger.recent(adding: .portalDetected) }
      portal = url
      if status != .browserFailed { status = .portal }
    }
    if openedPortal {
      attempts += 1
      if attempts <= 2 { return 5 }
    }
    return 30
  }

  private func resetCandidate() {
    evidence = PortalEvidence()
    portal = nil
  }

  private func schedule(after seconds: Int, generation currentGeneration: Int) {
    nextCheck = .now.addingTimeInterval(Double(seconds))
    checking = Task { [weak self] in
      do {
        try await Task.sleep(for: .seconds(seconds))
      } catch {
        return
      }
      guard let self, self.generation == currentGeneration else { return }
      self.nextCheck = nil
      await self.check(generation: currentGeneration)
    }
  }
}
