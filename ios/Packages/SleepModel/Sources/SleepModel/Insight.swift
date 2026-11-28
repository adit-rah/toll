import Foundation

/// The one thing the model may tell someone: what starting the block 30 minutes earlier did. Only
/// this may be worded with "because", since only the start was randomized. The sentence itself lives
/// with the app's copy; this carries the numbers.
public struct Insight: Codable, Sendable, Equatable {
  public enum Kind: String, Codable, Sendable { case start30Earlier = "start_30_earlier" }

  public var kind: Kind
  /// Minutes sooner asleep when the block started 30 minutes earlier; negative means later.
  public var minutes: Double
  public var low: Double
  public var high: Double
  public var nights: Int
}

extension SleepModel {
  /// The start effect and its posterior sd, from κ²Σ.
  public func startEffect() -> (minutes: Double, sd: Double) {
    let l = factor
    let v = Linear4.forward(l, [0, 1, 0, 0])
    let sd = (v[0] * v[0] + v[1] * v[1] + v[2] * v[2] + v[3] * v[3]).squareRoot()
    return (artifact.base.theta[1] + mean(l)[1], sd)
  }

  /// Shown only with enough nights, a shown range narrower than `maxWidthMin`, and a stricter
  /// zero test clear of zero: checking every night is many looks, and the stricter range keeps
  /// false insights under 5% (datascience/reports/tuning.md), for as long as Dusk is used
  /// (`zeroTestLevel`). An insight already showing (`PersonState.shown`) stays while the
  /// untightened test holds, and is no longer returned when even that fails.
  public func insights() -> [Insight] {
    let check = insightCheck()
    guard check.shown else { return [] }
    return [
      Insight(
        kind: .start30Earlier, minutes: check.effect, low: check.low, high: check.high,
        nights: state.nights)
    ]
  }

  /// The insight rule's numbers whether or not it shows; personal timing settles on them (`Hold`).
  /// When the noise's scale is learned (#154), the zero tests are a t's, with the weeks the scale
  /// rests on as degrees of freedom; the range shown stays a normal's.
  func insightCheck() -> (shown: Bool, effect: Double, low: Double, high: Double) {
    let (effect, sd) = startEffect()
    let rule = artifact.insight
    let z = normalQuantile(0.5 + rule.interval / 2.0)
    var strict = normalQuantile(0.5 + rule.zeroTestLevel(nights: state.nights) / 2.0)
    var base = normalQuantile(0.5 + rule.zeroTestInterval / 2.0)
    if (artifact.noiseScalePriorNights ?? 0) > 0 {
      let nu = scaleWeeks
      strict = widen(strict, nu)
      base = widen(base, nu)
    }
    let low = effect - z * sd
    let high = effect + z * sd
    func clear(_ z: Double) -> Bool { effect - z * sd > 0 || effect + z * sd < 0 }
    let shown =
      state.nights >= rule.minNights && high - low < rule.maxWidthMin
      && (clear(strict) || (state.shown && clear(base)))
    return (shown, effect, low, high)
  }
}

extension ModelArtifact.InsightRule {
  /// The zero test's interval after `nights` usable nights, as `dusk_model/insights.py`. Past
  /// `zeroTestSpendAfter` nights its miss chance shrinks as (after / nights) ^ power: the insight is
  /// checked every night for as long as Dusk is used, and one fixed test lets false insights grow
  /// past 5% (#117, datascience/reports/longrun.md).
  public func zeroTestLevel(nights: Int) -> Double {
    let after = zeroTestSpendAfter ?? 0
    guard after > 0, nights > after else { return zeroTestInterval }
    let shrink = pow(Double(after) / Double(nights), zeroTestSpendPower ?? 0)
    return 1.0 - (1.0 - zeroTestInterval) * shrink
  }
}

/// Acklam's rational approximation, as in `dusk_model/insights.py`.
func normalQuantile(_ p: Double) -> Double {
  let a = [
    -39.69683028665376, 220.9460984245205, -275.9285104469687, 138.3577518672690,
    -30.66479806614716, 2.506628277459239,
  ]
  let b = [
    -54.47609879822406, 161.5858368580409, -155.6989798598866, 66.80131188771972,
    -13.28068155288572,
  ]
  let c = [
    -0.007784894002430293, -0.3223964580411365, -2.400758277161838, -2.549732539343734,
    4.374664141464968, 2.938163982698783,
  ]
  let d = [0.007784695709041462, 0.3224671290700398, 2.445134137142996, 3.754408661907416]
  let low = 0.02425
  func tail(_ q: Double) -> Double {
    let num = ((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]
    return num / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1.0)
  }
  if p < low { return tail((-2.0 * log(p)).squareRoot()) }
  if p > 1.0 - low { return -tail((-2.0 * log(1.0 - p)).squareRoot()) }
  let q = p - 0.5
  let r = q * q
  let num = (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q
  return num / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1.0)
}
