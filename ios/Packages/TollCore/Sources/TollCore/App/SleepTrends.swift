import Foundation

/// Your sleep's measures (#87): when sleep began, how long it lasted, how steady its time is, and
/// how often the phone was reached for after the lock. Each compares the person's first nights with
/// their last week, and says a change only when it is larger than both a floor and their own night
/// to night noise (`TollConfig.Trends`). With too few nights a measure says nothing. Without Health's
/// sleep, Dusk's own nights stand in, named as what they are. Pure and tested.
public struct SleepTrends: Equatable, Sendable {
  public enum Kind: String, Sendable, CaseIterable {
    case asleepBy, timeAsleep, steadiness, reaches
    /// Dusk's own stand-ins when Health has no sleep: the last reach for a locked app, how steady
    /// that is, and the nights the lock ran.
    case phoneDown, phoneSteadiness, nightsLocked
  }

  /// Which way a change went, against the way this measure improves: earlier, longer, steadier,
  /// fewer reaches, more nights locked.
  public enum Way: Equatable, Sendable {
    case toward, away, steady
  }

  public struct Change: Equatable, Sendable {
    public var way: Way
    public var line: String
  }

  /// A range of values on the chart; a line when `low == high`.
  public struct Band: Equatable, Sendable {
    public var low: Double
    public var high: Double
  }

  /// The last `chartNights` nights, oldest first, with the first nights' level and the last
  /// week's drawn across it.
  public struct Chart: Equatable, Sendable {
    public enum Style: Equatable, Sendable {
      /// A time each night; earlier is drawn higher, as a day reads down.
      case times
      case bars
    }

    public var style: Style
    public var values: [Double?]
    public var first: Band?
    public var recent: Band?
    /// How many of the last columns the recent band spans.
    public var recentColumns: Int
  }

  public struct Measure: Equatable, Sendable, Identifiable {
    public var kind: Kind
    /// "11:20 pm", "7 h 35 m", "± 20 min", "1.4", "6 of 7".
    public var value: String
    /// What the value is: "Average, last 7 nights".
    public var detail: String
    /// Nil until there are first nights and enough recent ones to compare.
    public var change: Change?
    /// Dusk's counts beside it: "Locked 6 of the last 7 nights", "2 pauses in the last 7 nights".
    public var context: String?
    public var chart: Chart
    public var spoken: String
    public var id: Kind { kind }

    /// A stand-in from Dusk's own nights, not measured sleep.
    public var standIn: Bool { [.phoneDown, .phoneSteadiness, .nightsLocked].contains(kind) }
  }

  /// What the section says about where its numbers come from.
  public enum Source: Equatable, Sendable {
    /// Health's sleep.
    case health
    /// Health was chosen and has no recent sleep: a watch adds it.
    case healthEmpty
    /// Health wasn't chosen: Dusk's own nights, and a way to add Health.
    case dusk
  }

  public var measures: [Measure]
  public var source: Source

  public init(
    nights past: [PastNight], health: Bool, now: Date, calendar: Calendar,
    config: TollConfig = .defaults
  ) {
    let rules = config.trends
    let reader = Reader(
      past: past, anchor: calendar.startOfDay(for: now.addingTimeInterval(-12 * 3600)),
      calendar: calendar, rules: rules)
    let onsets = reader.series { night in
      night.slept.map { reader.minutesFromNoon($0.onset, night: night.night) }
    }
    let recentSleep = onsets.filter { reader.isRecent($0.night) }.count
    source = recentSleep >= rules.minShow ? .health : health ? .healthEmpty : .dusk
    var measures: [Measure] = []
    if source == .health {
      let asleep = reader.series { $0.slept.map { Double($0.minutes) } }
      measures += [
        reader.mean(.asleepBy, onsets, lowerIsBetter: true, floor: rules.floorMinutes),
        reader.mean(.timeAsleep, asleep, lowerIsBetter: false, floor: rules.floorMinutes),
        reader.spread(.steadiness, onsets),
      ].compactMap { $0 }
    } else {
      let reach = reader.series { night in
        night.ran ? night.lastReach.map { reader.minutesFromNoon($0, night: night.night) } : nil
      }
      measures += [
        reader.mean(.phoneDown, reach, lowerIsBetter: true, floor: rules.floorMinutes),
        reader.nightsLocked(),
        reader.spread(.phoneSteadiness, reach),
      ].compactMap { $0 }
    }
    let reaches = reader.series { night in
      night.ran ? (night.reaches ?? night.taps?.count).map(Double.init) : nil
    }
    if var measure = reader.mean(
      .reaches, reaches, lowerIsBetter: true, floor: rules.floorReaches)
    {
      measure.context = reader.pausesLine()
      measures.append(measure)
    }
    if source == .health, let first = measures.firstIndex(where: { $0.kind == .asleepBy }) {
      measures[first].context = reader.lockedLine()
    }
    self.measures = measures
  }

  public var isEmpty: Bool { measures.isEmpty }
}

/// A value for each night that has one, oldest first.
typealias NightSeries = [(night: Date, value: Double)]

/// Reads the measures from the nights: which are recent, the first nights, and each comparison.
struct Reader {
  let past: [PastNight]
  /// Last night's key in the morning, tonight's in the evening: the recent nights end here.
  let anchor: Date
  let calendar: Calendar
  let rules: TollConfig.Trends

  func series(_ value: (PastNight) -> Double?) -> NightSeries {
    past.compactMap { night in value(night).map { (night.night, $0) } }
  }

  func minutesFromNoon(_ date: Date, night: Date) -> Double {
    let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: night) ?? night
    return date.timeIntervalSince(noon) / 60
  }

  func isRecent(_ night: Date, nights: Int? = nil) -> Bool {
    let back = (nights ?? rules.recentNights) - 1
    guard let from = calendar.date(byAdding: .day, value: -back, to: anchor) else { return false }
    return night >= from && night <= anchor
  }

  /// A measure that's an average a night: falling asleep, the minutes asleep, reaches.
  func mean(_ kind: SleepTrends.Kind, _ series: NightSeries, lowerIsBetter: Bool, floor: Double)
    -> SleepTrends.Measure?
  {
    let recent = series.filter { isRecent($0.night) }
    guard recent.count >= rules.minShow else { return nil }
    let now = Stats.mean(recent.map(\.value))
    let first = Array(series.prefix(rules.baselineNights))
    let later = recent.filter { $0.night > (first.last?.night ?? .distantFuture) }
    var change: SleepTrends.Change?
    var firstLevel: Double?
    if first.count == rules.baselineNights, later.count >= rules.minRecent {
      let then = first.map(\.value)
      let after = later.map(\.value)
      let d = Stats.mean(after) - Stats.mean(then)
      firstLevel = Stats.mean(then)
      let way = Stats.way(
        d, se: Stats.standardError(then, after), z: rules.z, floor: floor,
        lowerIsBetter: lowerIsBetter)
      change = SleepTrends.Change(
        way: way, line: Copy.Trends.change(kind, by: d, way: way, first: first.count))
    }
    let value = Copy.Trends.value(kind, now, calendar: calendar, anchor: anchor)
    let detail = Copy.Trends.detail(kind, nights: recent.count)
    return SleepTrends.Measure(
      kind: kind, value: value, detail: detail, change: change,
      chart: chart(
        series, style: kind == .reaches || kind == .timeAsleep ? .bars : .times,
        first: firstLevel.map { .init(low: $0, high: $0) }, recent: .init(low: now, high: now)),
      spoken: Copy.Trends.spoken(kind, value: value, detail: detail, change: change?.line))
  }

  /// How steady a time is: the average distance of each night from the middle one, over two weeks,
  /// compared on those distances (a Brown–Forsythe test).
  func spread(_ kind: SleepTrends.Kind, _ series: NightSeries) -> SleepTrends.Measure? {
    let recent = series.filter { isRecent($0.night, nights: rules.steadyNights) }
    guard recent.count >= rules.minSteady else { return nil }
    let nowDevs = Stats.deviations(recent.map(\.value))
    let now = Stats.mean(nowDevs)
    let middle = Stats.median(recent.map(\.value))
    let first = Array(series.prefix(rules.steadyNights))
    let later = recent.filter { $0.night > (first.last?.night ?? .distantFuture) }
    var change: SleepTrends.Change?
    var firstBand: SleepTrends.Band?
    if first.count == rules.steadyNights, later.count >= rules.minSteadyRecent {
      let then = Stats.deviations(first.map(\.value))
      let after = Stats.deviations(later.map(\.value))
      let d = Stats.mean(after) - Stats.mean(then)
      let thenMiddle = Stats.median(first.map(\.value))
      firstBand = .init(low: thenMiddle - Stats.mean(then), high: thenMiddle + Stats.mean(then))
      let way = Stats.way(
        d, se: Stats.standardError(then, after), z: rules.z, floor: rules.floorSteady,
        lowerIsBetter: true)
      change = SleepTrends.Change(
        way: way,
        line: Copy.Trends.steadyChange(from: Stats.mean(then), way: way, first: first.count))
    }
    let value = Copy.Trends.spread(now)
    let detail = Copy.Trends.detail(kind, nights: recent.count)
    return SleepTrends.Measure(
      kind: kind, value: value, detail: detail, change: change,
      chart: chart(
        series, style: .times, first: firstBand,
        recent: .init(low: middle - now, high: middle + now), columns: rules.steadyNights),
      spoken: Copy.Trends.spoken(kind, value: value, detail: detail, change: change?.line))
  }

  /// The nights the lock ran, of the last seven, against the first seven: counts, not a sample, so
  /// only the floor applies.
  func nightsLocked() -> SleepTrends.Measure? {
    let series = series { $0.ran ? 1 : 0 }
    let recent = series.filter { isRecent($0.night) }
    guard recent.count >= rules.minShow else { return nil }
    let ran = Int(recent.map(\.value).reduce(0, +))
    let first = Array(series.prefix(rules.baselineNights))
    let later = recent.filter { $0.night > (first.last?.night ?? .distantFuture) }
    var change: SleepTrends.Change?
    if first.count == rules.baselineNights, later.count >= rules.minRecent {
      // Out of seven either way, so an evening's six ended nights compare too.
      let d =
        (Stats.mean(later.map(\.value)) - Stats.mean(first.map(\.value)))
        * Double(rules.baselineNights)
      let way: SleepTrends.Way =
        abs(d) < rules.floorNights ? .steady : d > 0 ? .toward : .away
      change = .init(
        way: way, line: Copy.Trends.change(.nightsLocked, by: d, way: way, first: first.count))
    }
    let value = Copy.Trends.of(ran, recent.count)
    let detail = Copy.Trends.detail(.nightsLocked, nights: recent.count)
    return SleepTrends.Measure(
      kind: .nightsLocked, value: value, detail: detail, change: change,
      chart: chart(series, style: .bars, first: nil, recent: nil),
      spoken: Copy.Trends.spoken(.nightsLocked, value: value, detail: detail, change: change?.line))
  }

  /// "Locked 6 of the last 7 nights": what Dusk did, beside the sleep it's for.
  func lockedLine() -> String? {
    let recent = past.filter { isRecent($0.night) }
    guard !recent.isEmpty else { return nil }
    return Copy.Trends.locked(recent.filter(\.ran).count, of: recent.count)
  }

  /// "2 pauses in the last 7 nights", from records that kept them.
  func pausesLine() -> String? {
    let recent = past.filter { isRecent($0.night) && $0.ran }.compactMap(\.pauses)
    guard !recent.isEmpty else { return nil }
    return Copy.Trends.pauses(recent.reduce(0, +), nights: rules.recentNights)
  }

  func chart(
    _ series: NightSeries, style: SleepTrends.Chart.Style, first: SleepTrends.Band?,
    recent: SleepTrends.Band?, columns: Int? = nil
  ) -> SleepTrends.Chart {
    let count = rules.chartNights
    let byNight = Dictionary(series.map { ($0.night, $0.value) }, uniquingKeysWith: { a, _ in a })
    let values: [Double?] = (0..<count).map { column in
      calendar.date(byAdding: .day, value: column - count + 1, to: anchor).flatMap { byNight[$0] }
    }
    return SleepTrends.Chart(
      style: style, values: values, first: first, recent: recent,
      recentColumns: min(count, columns ?? rules.recentNights))
  }
}

/// The few statistics the trends need.
enum Stats {
  static func mean(_ values: [Double]) -> Double {
    values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
  }

  static func variance(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }
    let m = mean(values)
    return values.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(values.count - 1)
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

  /// Welch's: the standard error of a difference of two means with unequal spreads.
  static func standardError(_ a: [Double], _ b: [Double]) -> Double {
    (variance(a) / Double(max(1, a.count)) + variance(b) / Double(max(1, b.count))).squareRoot()
  }

  /// A change counts when it clears both the floor and `z` standard errors.
  static func way(_ d: Double, se: Double, z: Double, floor: Double, lowerIsBetter: Bool)
    -> SleepTrends.Way
  {
    guard abs(d) >= floor, abs(d) >= z * se else { return .steady }
    return (d < 0) == lowerIsBetter ? .toward : .away
  }
}
