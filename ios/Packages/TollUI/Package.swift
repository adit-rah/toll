// swift-tools-version: 6.0
import PackageDescription

// iOS only: the components use the number pad, one-time-code autofill and UIKit colour providers, and
// the one consumer (TollFeatures) is iOS only.
let package = Package(
  name: "TollUI",
  platforms: [.iOS(.v18)],
  products: [.library(name: "TollUI", targets: ["TollUI"])],
  dependencies: [.package(path: "../TollCore")],
  targets: [
    .target(name: "TollUI", dependencies: [.product(name: "TollCore", package: "TollCore")])
  ]
)
