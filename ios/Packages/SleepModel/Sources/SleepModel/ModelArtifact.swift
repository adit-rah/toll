import Foundation

/// The JSON file of numbers exported from `datascience/` (model spec, contract 2). The app never
/// fits anything; it reads this.
public struct ModelArtifact: Codable, Sendable, Equatable {
  public struct Base: Codable, Sendable, Equatable { public var theta: [Double] }
  public struct Prior: Codable, Sendable, Equatable {
    public var mean: [Double]
    public var sd: [Double]
    enum CodingKeys: String, CodingKey {
      case mean
      case sd = "cov_diag_sd"
    }
  }
  public struct Policy: Codable, Sendable, Equatable {
    public var minProb: Double
    public var probDraws: Int
    enum CodingKeys: String, CodingKey {
      case minProb = "min_prob"
      case probDraws = "prob_draws"
    }
  }
  public struct Context: Codable, Sendable, Equatable {
    public var lateHomeWithinMin: Double
    enum CodingKeys: String, CodingKey { case lateHomeWithinMin = "late_home_within_min" }
  }
  public struct UsableNight: Codable, Sendable, Equatable {
    public var maxOnsetFromPlanMin: Double
    public var residualClipMin: Double
    enum CodingKeys: String, CodingKey {
      case maxOnsetFromPlanMin = "max_onset_from_plan_min"
      case residualClipMin = "residual_clip_min"
    }
  }
  public struct InsightRule: Codable, Sendable, Equatable {
    public var interval: Double
    public var zeroTestInterval: Double
    public var maxWidthMin: Double
    public var minNights: Int
    enum CodingKeys: String, CodingKey {
      case interval
      case zeroTestInterval = "zero_test_interval"
      case maxWidthMin = "max_width_min"
      case minNights = "min_nights"
    }
  }

  public var schema: Int
  public var version: String
  public var features: [String]
  public var base: Base
  public var prior: Prior
  public var noiseSd: Double
  public var forgetting: Double
  public var actions: [Int]
  public var policy: Policy
  public var context: Context
  public var usableNight: UsableNight
  public var insight: InsightRule
  public var sha256: String?

  enum CodingKeys: String, CodingKey {
    case schema, version, features, base, prior, forgetting, actions, policy, context, insight
    case sha256
    case noiseSd = "noise_sd"
    case usableNight = "usable_night"
  }

  public static let schemaVersion = 1
  public static let featureNames = ["intercept", "offset_per_30", "weekend", "late"]

  public enum Invalid: Error, Equatable {
    case schema(Int)
    case shape(String)
  }

  /// The same checks as `dusk_model/artifact.py`.
  public func validate() throws {
    guard schema == Self.schemaVersion else { throw Invalid.schema(schema) }
    guard features == Self.featureNames else { throw Invalid.shape("features") }
    guard base.theta.count == 4, prior.mean.count == 4, prior.sd.count == 4 else {
      throw Invalid.shape("theta, prior mean and prior sd take 4 numbers")
    }
    guard prior.sd.allSatisfy({ $0 > 0 }), noiseSd > 0 else {
      throw Invalid.shape("standard deviations must be positive")
    }
    guard forgetting > 0, forgetting <= 1 else { throw Invalid.shape("forgetting") }
    guard actions.contains(0), Set(actions).count == actions.count else {
      throw Invalid.shape("actions")
    }
    guard policy.minProb >= 0, policy.minProb * Double(actions.count) <= 1, policy.probDraws > 0
    else { throw Invalid.shape("policy") }
    guard insight.interval > 0, insight.interval <= insight.zeroTestInterval,
      insight.zeroTestInterval < 1
    else { throw Invalid.shape("interval") }
  }

  public static func decode(_ data: Data) throws -> ModelArtifact {
    let artifact = try JSONDecoder().decode(ModelArtifact.self, from: data)
    try artifact.validate()
    return artifact
  }

  /// The artifact shipped in the package, or the built-in defaults if it is missing or invalid, so
  /// the block never depends on the model.
  public static func bundled() -> ModelArtifact {
    guard let url = Bundle.module.url(forResource: "sleep-model.v0", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let artifact = try? decode(data)
    else { return builtIn }
    return artifact
  }

  /// sleep-model.v0's numbers; a test keeps them equal to the shipped file.
  public static let builtIn = ModelArtifact(
    schema: 1, version: "sleep-model.v0", features: featureNames,
    base: Base(theta: [15, 0, 30, 20]),
    prior: Prior(mean: [0, 0, 0, 0], sd: [20, 20, 20, 20]),
    noiseSd: 30, forgetting: 0.99, actions: [-30, 0, 30],
    policy: Policy(minProb: 0.1, probDraws: 1000),
    context: Context(lateHomeWithinMin: 60),
    usableNight: UsableNight(maxOnsetFromPlanMin: 240, residualClipMin: 90),
    insight: InsightRule(interval: 0.9, zeroTestInterval: 0.98, maxWidthMin: 30, minNights: 14),
    sha256: "")
}
