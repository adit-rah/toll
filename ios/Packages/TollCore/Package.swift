// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TollCore",
  platforms: [.iOS("26.5"), .macOS(.v15)],
  products: [
    .library(name: "TollCore", targets: ["TollCore"]),
    .library(name: "TollScreenTime", targets: ["TollScreenTime"]),
  ],
  // Tests only: the night record must decode as the sleep model reads it (#51). The app's TollCore
  // doesn't link it.
  dependencies: [.package(path: "../SleepModel")],
  targets: [
    .target(name: "TollCore"),
    .target(name: "TollScreenTime", dependencies: ["TollCore"]),
    .testTarget(
      name: "TollCoreTests",
      dependencies: ["TollCore", .product(name: "SleepModel", package: "SleepModel")]),
  ]
)
