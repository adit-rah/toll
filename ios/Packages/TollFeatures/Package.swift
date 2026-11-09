// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TollFeatures",
  platforms: [.iOS(.v18)],
  products: [.library(name: "TollFeatures", targets: ["TollFeatures"])],
  dependencies: [
    .package(path: "../TollCore"),
    .package(path: "../TollData"),
    .package(path: "../TollUI"),
  ],
  targets: [
    .target(
      name: "TollFeatures",
      dependencies: [
        .product(name: "TollCore", package: "TollCore"),
        .product(name: "TollScreenTime", package: "TollCore"),
        .product(name: "TollData", package: "TollData"),
        .product(name: "TollUI", package: "TollUI"),
      ]
    )
  ]
)
