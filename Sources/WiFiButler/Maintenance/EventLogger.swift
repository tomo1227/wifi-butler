import Foundation
import OSLog

@MainActor
struct EventLogger {
  private let defaults = UserDefaults.standard
  private let logger = Logger(subsystem: "dev.wifibutler.app", category: "activity")
  private let key = "activity"

  func recent(adding kind: Activity.Kind? = nil) -> [Activity] {
    let previous = read()
    let cutoff = Date.now.addingTimeInterval(-7 * 86_400)
    var current = previous.filter { $0.date >= cutoff }
    if let kind { current.insert(Activity(kind: kind), at: 0) }
    if current.count > 300 { current = Array(current.prefix(300)) }
    if current.map(\.id) != previous.map(\.id) { write(current) }
    return current
  }

  private func read() -> [Activity] {
    guard let data = defaults.data(forKey: key) else { return [] }
    do {
      return try JSONDecoder().decode([Activity].self, from: data)
    } catch {
      logger.error("Could not decode activity history")
      return []
    }
  }

  private func write(_ events: [Activity]) {
    do {
      defaults.set(try JSONEncoder().encode(events), forKey: key)
    } catch {
      logger.error("Could not encode activity history")
    }
  }
}
