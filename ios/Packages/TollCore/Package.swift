// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TollCore",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [
    .library(name: "TollCore", targets: ["TollCore"]),
    .library(name: "TollScreenTime", targets: ["TollScreenTime"]),
  ],
  targets: [
    .target(name: "TollCore"),
    .target(name: "TollScreenTime", dependencies: ["TollCore"]),
  ]
)
