/// One person's adapter: the precision matrix Λ (row by row), the vector b, the usable nights, and
/// whether the insight showed after the last of them (an insight showing keeps a laxer test, #117).
/// Since schema 3 (#154) it also carries the calendar week of the last usable night, so the usual
/// time can wander between weeks, and the forgetting sums the noise's scale is learned from.
/// The app keeps the night records too, so a new base can rebuild this in one pass.
public struct PersonState: Codable, Sendable, Equatable {
  public var precision: [Double]
  public var b: [Double]
  public var nights: Int
  public var shown: Bool
  /// Whole weeks since 2001-01-01 (a Monday) of the last usable night; nil before one.
  public var week: Int?
  public var scaleSum: Double
  public var scaleNights: Double

  public init(
    precision: [Double], b: [Double], nights: Int, shown: Bool = false, week: Int? = nil,
    scaleSum: Double = 0, scaleNights: Double = 0
  ) {
    self.precision = precision
    self.b = b
    self.nights = nights
    self.shown = shown
    self.week = week
    self.scaleSum = scaleSum
    self.scaleNights = scaleNights
  }

  enum CodingKeys: String, CodingKey {
    case precision, b, nights, shown, week
    case scaleSum = "scale_sum"
    case scaleNights = "scale_nights"
  }

  /// A state written before `shown` (sleep-model.v0's caches) reads as not shown, and one written
  /// before schema 3 as no week and no sums.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    precision = try c.decode([Double].self, forKey: .precision)
    b = try c.decode([Double].self, forKey: .b)
    nights = try c.decode(Int.self, forKey: .nights)
    shown = try c.decodeIfPresent(Bool.self, forKey: .shown) ?? false
    week = try c.decodeIfPresent(Int.self, forKey: .week)
    scaleSum = try c.decodeIfPresent(Double.self, forKey: .scaleSum) ?? 0
    scaleNights = try c.decodeIfPresent(Double.self, forKey: .scaleNights) ?? 0
  }
}

/// A frozen base f(x, a) = θ·φ plus the person's 4 numbers w, learned one night at a time
/// (model spec, section 3). Same steps, in the same order, as `dusk_model/model.py`.
public struct SleepModel: Sendable {
  public let artifact: ModelArtifact
  public private(set) var state: PersonState

  public init(artifact: ModelArtifact, state: PersonState? = nil) {
    self.artifact = artifact
    self.state = state ?? Self.prior(artifact)
  }

  /// Rebuilds a person's state from their nights, e.g. when a new base ships.
  public init(artifact: ModelArtifact, nights: [NightRecord]) {
    self.init(artifact: artifact)
    for night in nights { update(with: night) }
  }

  static func prior(_ a: ModelArtifact) -> PersonState {
    var precision = [Double](repeating: 0, count: 16)
    var b = [Double](repeating: 0, count: 4)
    for i in 0..<4 {
      let variance = a.prior.sd[i] * a.prior.sd[i]
      precision[i * 4 + i] = 1.0 / variance
      b[i] = a.prior.mean[i] / variance
    }
    return PersonState(precision: precision, b: b, nights: 0)
  }

  static func phi(offset: Int, _ context: NightContext) -> [Double] {
    [1.0, Double(offset) / 30.0, context.weekend ? 1 : 0, context.late ? 1 : 0]
  }

  func base(_ phi: [Double]) -> Double { Linear4.dot(artifact.base.theta, phi) }

  /// κ²: how much noisier this person's nights are than `noiseSd`, squared; 1 until the artifact
  /// learns it (schema 3, #154).
  var scale2: Double {
    let a0 = artifact.noiseScalePriorNights ?? 0
    guard a0 > 0 else { return 1 }
    return (a0 + state.scaleSum) / (a0 + state.scaleNights)
  }

  /// Every range is drawn from κ²Σ: Λ/κ² and b/κ², so μ is the same.
  var effective: (precision: [Double], b: [Double]) {
    guard (artifact.noiseScalePriorNights ?? 0) > 0 else { return (state.precision, state.b) }
    let k2 = scale2
    return (state.precision.map { $0 / k2 }, state.b.map { $0 / k2 })
  }

  var factor: [Double] { Linear4.cholesky(effective.precision) }

  /// μ = Λ⁻¹ b.
  func mean(_ l: [Double]) -> [Double] { Linear4.backward(l, Linear4.forward(l, effective.b)) }

  /// False if the night was skipped (see `SkipReason`).
  @discardableResult
  public mutating func update(with night: NightRecord) -> Bool {
    let f = night.features(artifact)
    guard f.skip == nil else { return false }
    let phi = Self.phi(offset: f.offset, f.context)
    let s2 = artifact.noiseSd * artifact.noiseSd
    let clip = artifact.usableNight.residualClipMin
    let r = min(max(f.onset - base(phi), -clip), clip)
    var lam = state.precision
    var b = state.b
    if artifact.forgetting < 1 {
      let prior = Self.prior(artifact)
      for k in 0..<16 {
        lam[k] = prior.precision[k] + artifact.forgetting * (lam[k] - prior.precision[k])
      }
      for i in 0..<4 { b[i] = prior.b[i] + artifact.forgetting * (b[i] - prior.b[i]) }
    }
    let week = Day.number(night.night).map { Day.period($0, 7) }
    let sd = artifact.interceptWeekSd ?? 0
    if sd > 0, let week, let last = state.week {
      Self.wander(&lam, &b, q: sd * sd * Double(max(week - last, 0)))
    }
    var scaleSum = state.scaleSum
    var scaleNights = state.scaleNights
    if (artifact.noiseScalePriorNights ?? 0) > 0 {
      let l = Linear4.cholesky(lam)
      let e = r - Linear4.dot(phi, Linear4.backward(l, Linear4.forward(l, b)))
      let v = Linear4.forward(l, phi)
      let u = (e * e) / (Linear4.dot(v, v) + s2)
      scaleSum = artifact.forgetting * scaleSum + u
      scaleNights = artifact.forgetting * scaleNights + 1.0
    }
    for i in 0..<4 {
      for j in 0..<4 { lam[i * 4 + j] = lam[i * 4 + j] + (phi[i] * phi[j]) / s2 }
    }
    for i in 0..<4 { b[i] = b[i] + (phi[i] * r) / s2 }
    state = PersonState(
      precision: lam, b: b, nights: state.nights + 1, shown: state.shown, week: week ?? state.week,
      scaleSum: scaleSum, scaleNights: scaleNights)
    state.shown = insightCheck().shown
    return true
  }

  /// Σ + q·e₀e₀ᵀ with μ kept, in information form, as `wander` in `dusk_model/model.py`: the
  /// usual time may have moved since the last usable night's week. q = 0 changes nothing.
  static func wander(_ lam: inout [Double], _ b: inout [Double], q: Double) {
    let g = q / (1.0 + q * lam[0])
    let c = (0..<4).map { lam[$0 * 4] }
    let b0 = b[0]
    for i in 0..<4 {
      for j in 0..<4 { lam[i * 4 + j] = lam[i * 4 + j] - g * c[i] * c[j] }
      b[i] = b[i] - g * c[i] * b0
    }
  }

  /// Onset in minutes from planned bedtime if the block starts `offset` minutes from plan:
  /// mean f + φᵀμ, sd √(φᵀΣφ + κ²σ²), with Σ already κ²Λ⁻¹.
  public func predict(_ context: NightContext, offset: Int) -> (mean: Double, sd: Double) {
    let l = factor
    let phi = Self.phi(offset: offset, context)
    let m = base(phi) + Linear4.dot(phi, mean(l))
    let v = Linear4.forward(l, phi)
    return (m, (Linear4.dot(v, v) + scale2 * (artifact.noiseSd * artifact.noiseSd)).squareRoot())
  }
}
