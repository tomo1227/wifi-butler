import Foundation
import XCTest

@testable import WiFiButler

final class WiFiSpeedTestTests: XCTestCase {
  func testReadsCommandOutputAndConvertsThroughputToMbps() async throws {
    let result = try await WiFiSpeedTest.run(
      executable: URL(fileURLWithPath: "/usr/bin/printf"),
      arguments: ["%s", #"{"dl_throughput":125400000,"ul_throughput":19450000}"#]
    )

    XCTAssertEqual(result.downloadMbps, 125.4, accuracy: 0.001)
    XCTAssertEqual(result.uploadMbps, 19.45, accuracy: 0.001)
  }

  func testRejectsFailedProcess() async throws {
    do {
      _ = try await WiFiSpeedTest.run(
        executable: URL(fileURLWithPath: "/usr/bin/false"), arguments: [])
      XCTFail("Expected a process failure")
    } catch WiFiSpeedTest.Failure.unsuccessfulProcess(let status) {
      XCTAssertNotEqual(status, 0)
    }
  }

  func testRejectsIncompleteOrFailedResults() {
    for output in [
      "",
      #"{"dl_throughput":1000000}"#,
      #"{"dl_throughput":0,"ul_throughput":1000000}"#,
      #"{"dl_throughput":1000000,"ul_throughput":1000000,"error_code":1}"#,
    ] {
      XCTAssertThrowsError(
        try JSONDecoder().decode(WiFiSpeedTestResult.self, from: Data(output.utf8)))
    }
  }

  @MainActor
  func testDoesNotMeasureWhenWiFiIsUnavailable() {
    let model = WiFiSpeedTestModel(interfaceName: { nil })

    model.start()

    XCTAssertEqual(model.state, .noWiFi)
  }

  @MainActor
  func testMeasuresSelectedInterfaceAndIgnoresDuplicateStart() async throws {
    let expected = try JSONDecoder().decode(
      WiFiSpeedTestResult.self,
      from: Data(#"{"dl_throughput":2000000,"ul_throughput":1000000}"#.utf8))
    var measuredInterfaces: [String] = []
    let model = WiFiSpeedTestModel(
      interfaceName: { "en7" },
      measure: { interface in
        measuredInterfaces.append(interface)
        return expected
      }
    )

    model.start()
    model.start()
    XCTAssertEqual(model.state, .measuring)
    let deadline = ContinuousClock.now + .seconds(2)
    while model.state == .measuring, ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(5))
    }

    XCTAssertEqual(measuredInterfaces, ["en7"])
    XCTAssertEqual(model.state, .completed(expected))
  }
}
