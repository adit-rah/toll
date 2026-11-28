/// Schema 3 (#154): a person's usual time can move, and their nights can be noisier than `noiseSd`.
/// The same steps, in the same order, as `dusk_model/model.py`.
///
/// Each usable night's residual, before the night is learned, is divided by its predicted sd. If the
/// model is right these are independent with variance 1, so a week's sum, squared, is about its
/// count of nights. When the nights are noisier, or the usual time moves for days or weeks, the sums
/// grow: one week's residuals share a sign, and so do one week's and the next's. κ² is the forgetting
/// sum of the squared week sums and of each week's sum times the week before's, over the forgetting
/// count of their nights, with `noiseScalePriorNights` nights of 1 added, and never below 1. Every
/// range is drawn from κ²Σ, and the zero tests use a t with the scale's weeks as degrees of freedom.
extension SleepModel {
  /// κ², the current week included; 1 until the artifact learns the scale.
  var scale2: Double {
    let a0 = artifact.noiseScalePriorNights ?? 0
    guard a0 > 0 else { return 1 }
    let s = state
    let squares = s.scaleSum + s.weekSum * s.weekSum
    let cross = s.scaleCross + s.weekSum * s.lastWeekSum
    let k2 = (a0 + (squares + max(cross, 0.0))) / (a0 + (s.scaleNights + s.weekNights))
    return max(k2, Self.scaleFloor)
  }

  static let scaleFloor = 1.0

  /// The weeks of evidence κ² rests on, its prior included.
  var scaleWeeks: Double {
    ((artifact.noiseScalePriorNights ?? 0) + (state.scaleNights + state.weekNights)) / 7.0
  }

  /// Λ/κ² and b/κ²: μ is the same and Σ is κ²Σ.
  var effective: (precision: [Double], b: [Double]) {
    guard (artifact.noiseScalePriorNights ?? 0) > 0 else { return (state.precision, state.b) }
    let k2 = scale2
    return (state.precision.map { $0 / k2 }, state.b.map { $0 / k2 })
  }

  /// Σ + q·e₀e₀ᵀ with μ kept, in information form: Λ − g·c·cᵀ and b − g·c·b₀, with c Λ's first
  /// column and g = q / (1 + q·Λ₀₀). q = 0 changes nothing.
  static func wander(_ lam: inout [Double], _ b: inout [Double], q: Double) {
    let g = q / (1.0 + q * lam[0])
    let c = (0..<4).map { lam[$0 * 4] }
    let b0 = b[0]
    for i in 0..<4 {
      for j in 0..<4 { lam[i * 4 + j] = lam[i * 4 + j] - g * c[i] * c[j] }
      b[i] = b[i] - g * c[i] * b0
    }
  }

  /// Tonight's step before the night is learned: the intercept's wander since the last usable
  /// night's week, then the scale's sums with tonight's residual `r` (from the base) added.
  func wandered(
    _ lam: inout [Double], _ b: inout [Double], phi: [Double], r: Double, week: Int?
  ) -> PersonState {
    var s = state
    let known = week.flatMap { w in s.week.map { w - $0 } }
    let sd = artifact.interceptWeekSd ?? 0
    if sd > 0, let passed = known {
      Self.wander(&lam, &b, q: sd * sd * Double(max(passed, 0)))
    }
    guard (artifact.noiseScalePriorNights ?? 0) > 0 else { return s }
    let f = artifact.forgetting
    let new = (known ?? 0) > 0
    s.scaleSum = f * (s.scaleSum + (new ? s.weekSum * s.weekSum : 0.0))
    s.scaleCross = f * (s.scaleCross + (new ? s.weekSum * s.lastWeekSum : 0.0))
    s.scaleNights = f * (s.scaleNights + (new ? s.weekNights : 0.0))
    if new { s.lastWeekSum = known == 1 ? s.weekSum : 0.0 }
    let l = Linear4.cholesky(lam)
    let e = r - Linear4.dot(phi, Linear4.backward(l, Linear4.forward(l, b)))
    let v = Linear4.forward(l, phi)
    let s2 = artifact.noiseSd * artifact.noiseSd
    s.weekSum = (new ? 0.0 : s.weekSum) + e / (Linear4.dot(v, v) + s2).squareRoot()
    s.weekNights = (new ? 0.0 : s.weekNights) + 1.0
    return s
  }
}

/// A Student t quantile with `nu` degrees of freedom from the normal one: the Cornish–Fisher series
/// to 1/ν⁴ (Abramowitz and Stegun 26.7.5), as `widen` in `dusk_model/insights.py`.
func widen(_ z: Double, _ nu: Double) -> Double {
  let z2 = z * z
  let g1 = (z2 + 1.0) * z / 4.0
  let g2 = ((5.0 * z2 + 16.0) * z2 + 3.0) * z / 96.0
  let g3 = (((3.0 * z2 + 19.0) * z2 + 17.0) * z2 - 15.0) * z / 384.0
  let g4 = ((((79.0 * z2 + 776.0) * z2 + 1482.0) * z2 - 1920.0) * z2 - 945.0) * z / 92160.0
  return z + (g1 + (g2 + (g3 + g4 / nu) / nu) / nu) / nu
}
