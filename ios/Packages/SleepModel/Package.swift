// swift-tools-version: 6.0
import PackageDescription

// Pure Swift, Foundation only: no UIKit, HealthKit, Accelerate or simd, so `swift test` runs on Linux
// and the numbers match the Python reference in datascience/ (fixtures).
let package = Package(
  name: "SleepModel",
  platforms: [.iOS("26.5"), .macOS(.v15)],
  products: [
    .library(name: "SleepModel", targets: ["SleepModel"]),
    .executable(name: "sleep-model-replay", targets: ["sleep-model-replay"]),
  ],
  targets: [
    .target(name: "SleepModel", resources: [.copy("Resources/sleep-model.v0.json")]),
    .executableTarget(name: "sleep-model-replay", dependencies: ["SleepModel"]),
    .testTarget(
      name: "SleepModelTests", dependencies: ["SleepModel"], resources: [.copy("Fixtures")]),
  ]
)
