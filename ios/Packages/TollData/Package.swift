// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TollData",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [.library(name: "TollData", targets: ["TollData"])],
  dependencies: [
    .package(path: "../TollCore"),
    .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.12.0"),
    .package(url: "https://github.com/getsentry/sentry-cocoa.git", exact: "9.33.0"),
    .package(url: "https://github.com/TelemetryDeck/SwiftSDK.git", exact: "2.14.2"),
  ],
  targets: [
    .target(
      name: "TollData",
      dependencies: [
        .product(name: "TollCore", package: "TollCore"),
        .product(name: "TollScreenTime", package: "TollCore"),
        .product(name: "GRDB", package: "GRDB.swift"),
        .product(name: "Sentry", package: "sentry-cocoa"),
        .product(name: "TelemetryDeck", package: "SwiftSDK"),
      ]
    )
  ]
)
