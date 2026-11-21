/// Runs a sequence of nights through the model the way the app does each night: choose tonight's
/// start, predict every start, then learn from the night. The parity tests and `sleep-model-replay`
/// share it, so what the tests check is what the tool prints.
public struct ReplayStep: Codable, Sendable, Equatable {
  public struct Choice: Codable, Sendable, Equatable {
    public var offset: Int
    public var prob: Double
  }
  public struct Prediction: Codable, Sendable, Equatable {
    public var offset: Int
    public var mean: Double
    public var sd: Double
  }
  public struct Context: Codable, Sendable, Equatable {
    public var weekend: Bool
    public var late: Bool
  }

  public var context: Context
  public var choice: Choice
  public var predictions: [Prediction]
  public var used: Bool
  public var skip: String?
  public var state: PersonState
  public var insights: [Insight]
  /// Hex, since JSON numbers lose 64-bit integers.
  public var rngState: String

  enum CodingKeys: String, CodingKey {
    case context, choice, predictions, used, skip, state, insights
    case rngState = "rng_state"
  }
}

public enum Replay {
  public static func run(
    artifact: ModelArtifact, nights: [NightRecord], seed: UInt64, allowed: [Int]? = nil
  ) -> [ReplayStep] {
    var model = SleepModel(artifact: artifact)
    var rng = SeededRNG(seed: seed)
    return nights.map { night in
      var context = night.context(artifact)
      context.allowedOffsets = allowed
      let choice = model.chooseOffset(context, rng: &rng)
      let predictions = artifact.actions.map { offset in
        let p = model.predict(context, offset: offset)
        return ReplayStep.Prediction(offset: offset, mean: p.mean, sd: p.sd)
      }
      let skip = night.features(artifact).skip
      let used = model.update(with: night)
      let hex = String(rng.state, radix: 16)
      return ReplayStep(
        context: .init(weekend: context.weekend, late: context.late),
        choice: .init(offset: choice.offset, prob: choice.prob),
        predictions: predictions, used: used, skip: skip?.rawValue, state: model.state,
        insights: model.insights(),
        rngState: String(repeating: "0", count: 16 - hex.count) + hex)
    }
  }
}
