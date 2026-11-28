import Foundation

/// Your sleep's change lines, judged once a week (#165, D99's week): on the week that ended before
/// the latest Monday noon, held until the next. `datascience/trends/rule.py` is the reference and its
/// fixtures keep the two equal. The values and charts still move nightly; only the line waits.
///
/// Each look compares trimmed means, so one wild night can't make or hide a change, against the
/// person's own night-to-night noise pooled over every week judged so far. The test is spent over the
/// looks: the k-th needs `miss · k^−spendPower`, so the chance of ever saying a change that isn't
/// there stays under 5% however long Dusk is used. A change said the week before, the same way, is
/// kept while it clears the first look's test, so the line doesn't flip back and forth.
struct TrendLook: Equatable {
  /// The night key of the Monday that judged it.
  var monday: Date
  /// How many weeks have been judged, this one included.
  var look: Int
  var d: Double
  var way: SleepTrends.Way
}

extension Reader {
  /// The Monday that starts the week holding `night`.
  func monday(of night: Date) -> Date {
    let back = (calendar.component(.weekday, from: night) - weekday + 7) % 7
    return day(-back, from: night)
  }

  func day(_ n: Int, from night: Date) -> Date {
    calendar.date(byAdding: .day, value: n, to: night) ?? night
  }

  /// Every week's judgement up to the one in force now, oldest first, and the first nights' values.
  /// For How steady (`steady`), each window's distances from its middle night are compared, over
  /// two weeks.
  func looks(_ series: NightSeries, floor: Double, lowerIsBetter: Bool, steady: Bool = false)
    -> (looks: [TrendLook], then: [Double])
  {
    let size = steady ? rules.steadyNights : rules.baselineNights
    let least = steady ? rules.minSteadyRecent : rules.minRecent
    let window = steady ? rules.steadyNights : 7
    let ordered = series.sorted { $0.night < $1.night }
    let center: ([Double]) -> [Double] = steady ? Stats.distances : { $0 }
    guard ordered.count >= size, let end = ordered.prefix(size).last?.night else { return ([], []) }
    let then = center(ordered.prefix(size).map(\.value))
    var blocks = [then]
    var found: [TrendLook] = []
    var held: SleepTrends.Way?
    var monday = day(7, from: self.monday(of: end))
    let last = self.monday(of: anchor)
    while monday <= last {
      let from = day(-window, from: monday)
      let later = ordered.filter { $0.night >= from && $0.night < monday && $0.night > end }
      if later.count >= least {
        let after = center(later.map(\.value))
        // Weeks don't overlap, so every one judged adds to the person's noise; How steady's
        // windows do, so it reads its own two.
        if !steady { blocks.append(after) }
        let se = Stats.standardError(
          Stats.pooledSpread(steady ? [then, after] : blocks, trim: rules.trim), then.count,
          after.count, trim: rules.trim)
        let d = Stats.trimmed(after, rules.trim) - Stats.trimmed(then, rules.trim)
        let look = found.count + 1
        let way: SleepTrends.Way = (d < 0) == lowerIsBetter ? .toward : .away
        let clears = abs(d) >= floor
        let result: SleepTrends.Way =
          clears && held == way && abs(d) >= z(1) * se
          ? way : clears && abs(d) >= z(look) * se ? way : .steady
        held = result == .steady ? nil : result
        found.append(TrendLook(monday: monday, look: look, d: d, way: result))
      }
      monday = day(7, from: monday)
    }
    return (found, then)
  }

  /// The judgement the screen shows: the latest week's, if that week was judged.
  func inForce(_ found: [TrendLook]) -> TrendLook? {
    found.last.flatMap { $0.monday == monday(of: anchor) ? $0 : nil }
  }

  /// The k-th look's test: its miss chance is the first's, shrinking as k^−spendPower.
  func z(_ look: Int) -> Double {
    Stats.normalQuantile(1 - rules.miss * pow(Double(look), -rules.spendPower) / 2)
  }
}

/// The few statistics the trends need.
enum Stats {
  static func mean(_ values: [Double]) -> Double {
    values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
  }

  static func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    guard !sorted.isEmpty else { return 0 }
    let mid = sorted.count / 2
    return sorted.count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
  }

  /// Each value's distance from the middle one.
  static func deviations(_ values: [Double]) -> [Double] {
    let middle = median(values)
    return values.map { abs($0 - middle) }
  }

  static func distances(_ values: [Double]) -> [Double] { deviations(values) }

  /// How many values a trimmed mean sets aside at each end.
  static func cut(_ n: Int, _ trim: Double) -> Int { Int((trim * Double(n) + 1e-9).rounded(.down)) }

  /// The mean with the highest and lowest `trim` of the values set aside.
  static func trimmed(_ values: [Double], _ trim: Double) -> Double {
    let sorted = values.sorted()
    let g = cut(sorted.count, trim)
    guard sorted.count > 2 * g else { return 0 }
    return mean(Array(sorted[g..<(sorted.count - g)]))
  }

  /// The values with the highest and lowest `trim` pulled in to the nearest kept one.
  static func winsorized(_ values: [Double], _ trim: Double) -> [Double] {
    let sorted = values.sorted()
    let g = cut(sorted.count, trim)
    guard g > 0, sorted.count > 2 * g else { return values }
    let low = sorted[g]
    let high = sorted[sorted.count - 1 - g]
    return values.map { min(max($0, low), high) }
  }

  /// The night-to-night noise of several weeks: each winsorized about its own mean, pooled.
  static func pooledSpread(_ blocks: [[Double]], trim: Double) -> Double {
    var squares = 0.0
    var count = 0
    for block in blocks where block.count >= 2 {
      let kept = winsorized(block, trim)
      let m = kept.reduce(0, +) / Double(kept.count)
      squares += kept.map { ($0 - m) * ($0 - m) }.reduce(0, +)
      count += kept.count - 1
    }
    return count > 0 ? (squares / Double(count)).squareRoot() : 0
  }

  /// Of a difference of two trimmed means: each mean's error is the spread over (1 − 2g/n)·√n
  /// (Tukey and McLaughlin).
  static func standardError(_ spread: Double, _ a: Int, _ b: Int, trim: Double) -> Double {
    func share(_ n: Int) -> Double {
      let kept = Double(n - 2 * cut(n, trim))
      return Double(n) / (kept * kept)
    }
    return spread * (share(a) + share(b)).squareRoot()
  }

  /// Acklam's rational approximation, as in `dusk_model/insights.py`.
  static func normalQuantile(_ p: Double) -> Double {
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
}
