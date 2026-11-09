// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TollUI",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [.library(name: "TollUI", targets: ["TollUI"])],
  dependencies: [.package(path: "../TollCore")],
  targets: [
    .target(name: "TollUI", dependencies: [.product(name: "TollCore", package: "TollCore")])
  ]
)
