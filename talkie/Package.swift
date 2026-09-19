// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "Talkie",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "Talkie", targets: ["Talkie"])],
  targets: [
    .target(name: "TalkieCore"),
    .executableTarget(name: "Talkie", dependencies: ["TalkieCore"]),
    .testTarget(name: "TalkieCoreTests", dependencies: ["TalkieCore"]),
  ]
)
