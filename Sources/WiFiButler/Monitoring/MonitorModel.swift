import AppKit
import ButlerCore
import Observation

@MainActor
@Observable
final class MonitorModel {
  private let wifi = WiFiMonitor()
  private let connectivity = ConnectivityMonitor()
  private let controller = BrowserController()
  private let logger = EventLogger()
  private var checking: Task<Void, Never>?
  private var reconnecting: Task<Void, Never>?
  private var reconnectPolicy = WiFiReconnectPolicy()
  private var portalAfterReconnect: (ssid: String, expires: ContinuousClock.Instant)?
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
  private(set) var reconnectFailed = false
  var autoReconnect = true
  var browser = Browser.dia

  var canReconnect: Bool {
    isMonitoring && !sleeping && reconnecting == nil && !opening
      && reconnectPolicy.manualTarget(for: snapshot) != nil && wifi.canReconnect
  }

  init() {
    activities = logger.recent()
    lastVerified = activities.first { $0.kind == .verified }?.date
    wifi.start { [weak self] in self?.refreshAfterPathChange() }
  }

  func setMonitoring(_ enabled: Bool) {
    isMonitoring = enabled
    if enabled { wifi.requestLocationPermission() }
    if !enabled {
      cancelReconnect()
      reconnectPolicy = WiFiReconnectPolicy()
      reconnectFailed = false
    }
    resetCandidate()
    openedPortal = false
    refresh()
  }

  func requestLocationPermission() {
    wifi.requestLocationPermission()
  }

  func setSleeping(_ value: Bool) {
    sleeping = value
    if value { cancelReconnect() }
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
    guard reconnecting == nil else {
      status = .reconnecting
      return
    }
    let currentGeneration = generation
    checking = Task { [weak self] in await self?.check(generation: currentGeneration) }
  }

  func reconnect() {
    guard canReconnect, let ssid = reconnectPolicy.manualTarget(for: wifi.snapshot()) else {
      return
    }
    startReconnect(to: ssid, force: true)
  }

  func openDetectedPortal() {
    guard let portal else { return }
    Task { await openPortal(portal) }
  }

  func openPortal(_ url: URL) async {
    let current = snapshot
    guard !opening, status == .portal || status == .browserFailed, url == portal,
      isMonitoring, !sleeping
    else { return }
    guard isCurrentNetwork(current) else { return refresh() }
    generation += 1
    checking?.cancel()
    nextCheck = nil
    let currentGeneration = generation
    opening = true
    defer { opening = false }
    status = .opening
    let app = await controller.open(url, in: browser)
    guard generation == currentGeneration else { return }
    guard isCurrentNetwork(current) else { return refresh() }
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

  private func isCurrentNetwork(_ expected: WiFiSnapshot) -> Bool {
    SupportedWiFi.matches(wifi.snapshot(), expected: expected) && wifi.hasWiFiRoute
  }

  private func refreshAfterPathChange() {
    guard isMonitoring, !sleeping, reconnecting == nil else { return }
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
    reconnectPolicy.observe(current)
    let networkChanged = current != snapshot
    if networkChanged {
      resetCandidate()
      openedPortal = false
      if case .connected(let ssid) = current {
        if portalAfterReconnect?.ssid != ssid { portalAfterReconnect = nil }
        reconnectFailed = false
      }
    }
    snapshot = current
    if autoReconnect, !opening, wifi.canReconnect,
      let ssid = reconnectPolicy.takeAutomaticTarget(for: current)
    {
      startReconnect(to: ssid, force: false)
      return
    }
    if let blocked = blockedStatus(current) {
      status = blocked
      schedule(after: 30, generation: currentGeneration)
      return
    }
    if networkChanged || (status != .portal && status != .browserFailed) { status = .checking }
    let result = await connectivity.check { [weak self] in
      guard let self else { return false }
      return self.generation == currentGeneration && self.isCurrentNetwork(current)
    }
    guard !Task.isCancelled, generation == currentGeneration else { return }
    guard isCurrentNetwork(current) else { return refresh() }
    let delay = record(result)
    if let pending = portalAfterReconnect {
      if ContinuousClock.now >= pending.expires || result == .online {
        portalAfterReconnect = nil
      } else if current == .connected(pending.ssid), let portal, !opening {
        portalAfterReconnect = nil
        checking = nil
        await openPortal(portal)
        return
      }
    }
    schedule(after: delay, generation: currentGeneration)
  }

  private func startReconnect(to ssid: String, force: Bool) {
    generation += 1
    checking?.cancel()
    nextCheck = nil
    resetCandidate()
    openedPortal = false
    portalAfterReconnect = nil
    reconnectFailed = false
    reconnectPolicy.markAttempt(for: ssid)
    status = .reconnecting
    reconnecting = Task { [weak self] in
      let outcome = await WiFiReconnector.reconnect(to: ssid, force: force)
      guard let self else { return }
      self.reconnecting = nil
      if !Task.isCancelled {
        switch outcome {
        case .joined:
          self.portalAfterReconnect = (ssid, ContinuousClock.now.advanced(by: .seconds(60)))
        case .failed:
          self.reconnectFailed = true
        case .superseded:
          break
        }
      }
      self.refresh()
    }
  }

  private func cancelReconnect() {
    reconnecting?.cancel()
    portalAfterReconnect = nil
  }

  private func blockedStatus(_ current: WiFiSnapshot) -> MonitorStatus? {
    switch current {
    case .disconnected: .disconnected
    case .unidentified: .unidentified
    case .connected where !current.isAllowed(by: SupportedWiFi.ssids): .excluded
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
