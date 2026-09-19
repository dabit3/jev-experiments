// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "Say",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "Say", targets: ["Say"])],
  targets: [
    .target(name: "SayCore"),
    .executableTarget(name: "Say", dependencies: ["SayCore"]),
    .testTarget(name: "SayCoreTests", dependencies: ["SayCore"]),
    .testTarget(name: "SayTests", dependencies: ["Say"]),
  ]
)
