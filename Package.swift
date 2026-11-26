// swift-tools-version: 6.4
import PackageDescription

let package = Package(
  name: "WiFiButler",
  platforms: [.macOS(.v15)],
  products: [.executable(name: "WiFiButler", targets: ["WiFiButler"])],
  targets: [
    .target(name: "ButlerCore"),
    .executableTarget(name: "WiFiButler", dependencies: ["ButlerCore"]),
    .testTarget(name: "ButlerCoreTests", dependencies: ["ButlerCore"]),
    .testTarget(name: "WiFiButlerTests", dependencies: ["WiFiButler", "ButlerCore"]),
  ]
)
