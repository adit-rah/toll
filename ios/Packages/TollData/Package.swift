// swift-tools-version: 6.0
import PackageDescription

// App only: the extensions import TollCore and nothing larger (spec §6 memory ceiling).
let package = Package(
  name: "TollData",
  platforms: [.iOS("26.5"), .macOS(.v15)],
  products: [.library(name: "TollData", targets: ["TollData"])],
  dependencies: [.package(path: "../TollCore")],
  targets: [
    .target(
      name: "TollData",
      dependencies: [
        .product(name: "TollCore", package: "TollCore"),
        .product(name: "TollScreenTime", package: "TollCore"),
      ]
    )
  ]
)
