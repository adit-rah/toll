/// One person's adapter: the precision matrix Λ (row by row), the vector b, and the usable nights.
/// The app keeps the night records too, so a new base can rebuild this in one pass.
public struct PersonState: Codable, Sendable, Equatable {
  public var precision: [Double]
  public var b: [Double]
  public var nights: Int

  public init(precision: [Double], b: [Double], nights: Int) {
    self.precision = precision
    self.b = b
    self.nights = nights
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

  var factor: [Double] { Linear4.cholesky(state.precision) }

  /// μ = Λ⁻¹ b.
  func mean(_ l: [Double]) -> [Double] { Linear4.backward(l, Linear4.forward(l, state.b)) }

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
    for i in 0..<4 {
      for j in 0..<4 { lam[i * 4 + j] = lam[i * 4 + j] + (phi[i] * phi[j]) / s2 }
    }
    for i in 0..<4 { b[i] = b[i] + (phi[i] * r) / s2 }
    state = PersonState(precision: lam, b: b, nights: state.nights + 1)
    return true
  }

  /// Onset in minutes from planned bedtime if the block starts `offset` minutes from plan:
  /// mean f + φᵀμ, sd √(φᵀΣφ + σ²).
  public func predict(_ context: NightContext, offset: Int) -> (mean: Double, sd: Double) {
    let l = factor
    let phi = Self.phi(offset: offset, context)
    let m = base(phi) + Linear4.dot(phi, mean(l))
    let v = Linear4.forward(l, phi)
    return (m, (Linear4.dot(v, v) + artifact.noiseSd * artifact.noiseSd).squareRoot())
  }
}
