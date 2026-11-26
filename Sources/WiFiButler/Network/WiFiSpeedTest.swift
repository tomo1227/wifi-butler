import Foundation

enum WiFiSpeedTest {
  enum Failure: Error {
    case unsuccessfulProcess(Int32)
  }

  static func measure(on interface: String) async throws -> WiFiSpeedTestResult {
    try await run(
      executable: URL(fileURLWithPath: "/usr/bin/networkQuality"),
      arguments: ["-I", interface, "-M", "20", "-c"]
    )
  }

  @concurrent
  static func run(executable: URL, arguments: [String]) async throws -> WiFiSpeedTestResult {
    let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }

    // A file lets the child write output without blocking on a full pipe.
    let output = directory.appending(path: "result.json")
    try Data().write(to: output)
    let stdout = try FileHandle(forWritingTo: output)
    defer { try? stdout.close() }

    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = stdout
    process.standardError = FileHandle.nullDevice

    let status: Int32 = try await withCheckedThrowingContinuation { continuation in
      process.terminationHandler = { child in
        continuation.resume(returning: child.terminationStatus)
      }
      do {
        try process.run()
      } catch {
        continuation.resume(throwing: error)
      }
    }
    guard status == 0 else { throw Failure.unsuccessfulProcess(status) }
    return try JSONDecoder().decode(WiFiSpeedTestResult.self, from: Data(contentsOf: output))
  }
}
