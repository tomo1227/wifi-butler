import Foundation

struct WiFiSpeedTestResult: Decodable, Equatable, Sendable {
  let downloadMbps: Double
  let uploadMbps: Double

  private enum CodingKeys: String, CodingKey {
    case download = "dl_throughput"
    case upload = "ul_throughput"
    case errorCode = "error_code"
    case errorDomain = "error_domain"
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    guard !values.contains(.errorCode), !values.contains(.errorDomain) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "networkQuality reported an error"))
    }

    let download = try values.decode(Double.self, forKey: .download)
    let upload = try values.decode(Double.self, forKey: .upload)
    guard download.isFinite, upload.isFinite, download > 0, upload > 0 else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Invalid throughput"))
    }

    downloadMbps = download / 1_000_000
    uploadMbps = upload / 1_000_000
  }
}
