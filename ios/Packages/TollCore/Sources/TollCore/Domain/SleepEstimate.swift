import Foundation

/// When the person usually falls asleep and wakes, from Health's recent nights (#144): the circular
/// median of each over the last `health.lookbackDays`, so 11:50 pm and 12:10 am average to midnight,
/// not noon. Weekends (Fri and Sat nights) are kept apart only when they differ enough to matter.
/// Pure: the Health adapter reads the samples; this decides.
public struct SleepEstimate: Equatable, Sendable {
  public struct Usual: Equatable, Sendable {
    public var asleep: ClockTime
    public var wake: ClockTime

    public init(asleep: ClockTime, wake: ClockTime) {
      self.asleep = asleep
      self.wake = wake
    }

    public var window: TimeWindow { TimeWindow(start: asleep, end: wake) }
  }

  /// Nights the estimate read.
  public var nights: Int
  /// Every night's usual times, or the weeknights' when weekends differ.
  public var usual: Usual
  /// Fri and Sat nights, only when they differ from the rest by `health.weekendSplitMinutes`.
  public var weekends: Usual?
  /// The median minutes from getting into bed to falling asleep, where the source gives both.
  public var latency: Int?
  /// How much the time of falling asleep varies: its standard deviation, in minutes.
  public var variability: Int?

  /// Nil with fewer than `health.minNights` recent nights: Dusk asks instead.
  public init?(
    _ all: [SleepNight], now: Date, calendar: Calendar, config: TollConfig = .defaults
  ) {
    let health = config.health
    let today = calendar.startOfDay(for: now)
    guard let from = calendar.date(byAdding: .day, value: -health.lookbackDays, to: today)
    else { return nil }
    let nights = all.filter { $0.night >= from && $0.wake <= now }
    guard nights.count >= health.minNights else { return nil }
    self.nights = nights.count
    let round = health.roundMinutes
    func times(_ group: [SleepNight]) -> Usual {
      Usual(
        asleep: Self.median(group.map { Self.clock($0.onset, calendar) }, round: round),
        wake: Self.median(group.map { Self.clock($0.wake, calendar) }, round: round))
    }
    let every = times(nights)
    let weekend = nights.filter { $0.weekend(calendar) }
    let week = nights.filter { !$0.weekend(calendar) }
    usual = every
    if weekend.count >= health.minWeekendNights, week.count >= health.minWeekendNights {
      let (a, b) = (times(week), times(weekend))
      let apart = max(
        Self.distance(a.asleep, b.asleep), Self.distance(a.wake, b.wake))
      if apart >= health.weekendSplitMinutes {
        usual = a
        weekends = b
      }
    }
    let latencies = nights.compactMap(\.latency).sorted()
    latency = latencies.count >= health.minWeekendNights ? latencies[latencies.count / 2] : nil
    variability = Self.spread(nights.map { Self.clock($0.onset, calendar) })
    guard usual.window.isValid, weekends?.window.isValid ?? true else { return nil }
  }

  /// The schedule these times make: one rule, or school nights and Fri and Sat nights.
  public var schedule: WeeklySchedule {
    guard let weekends else { return .everyDay(usual.window) }
    return WeeklySchedule(rules: [
      .init(days: Weekday.schoolNights, window: usual.window),
      .init(days: Weekday.weekendNights, window: weekends.window),
    ])
  }

  static func clock(_ date: Date, _ calendar: Calendar) -> Int {
    calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
  }

  /// Minutes between two times of day, the short way round.
  static func distance(_ a: ClockTime, _ b: ClockTime) -> Int {
    let d = abs(a.minuteOfDay - b.minuteOfDay) % 1440
    return min(d, 1440 - d)
  }

  /// Each time as minutes from the times' circular mean, in -720 ..< 720: on that line a median
  /// and a spread mean what they say, whichever side of midnight the times fall.
  static func offsets(_ minutes: [Int]) -> (anchor: Double, offsets: [Double]) {
    let angles = minutes.map { Double($0) / 1440 * 2 * .pi }
    let mean = atan2(angles.map(sin).reduce(0, +), angles.map(cos).reduce(0, +))
    let anchor = (mean / (2 * .pi) * 1440 + 1440).truncatingRemainder(dividingBy: 1440)
    let offsets = minutes.map { minute -> Double in
      let d = (Double(minute) - anchor + 720).truncatingRemainder(dividingBy: 1440)
      return (d < 0 ? d + 1440 : d) - 720
    }
    return (anchor, offsets)
  }

  /// The circular median, rounded to `round` minutes.
  static func median(_ minutes: [Int], round: Int) -> ClockTime {
    let (anchor, offsets) = offsets(minutes)
    let sorted = offsets.sorted()
    let middle =
      sorted.count % 2 == 1
      ? sorted[sorted.count / 2] : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
    let step = Double(max(1, round))
    let value = ((anchor + middle) / step).rounded() * step
    let minute = (Int(value) % 1440 + 1440) % 1440
    return ClockTime(hour: minute / 60, minute: minute % 60)
  }

  /// The standard deviation of the times around their circular mean, in whole minutes.
  static func spread(_ minutes: [Int]) -> Int? {
    guard minutes.count >= 2 else { return nil }
    let (_, offsets) = offsets(minutes)
    let mean = offsets.reduce(0, +) / Double(offsets.count)
    let variance = offsets.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(offsets.count)
    return Int(variance.squareRoot().rounded())
  }
}

/// The buffers' targets, suggestion v0 (#144; #145 replaces it with a model-backed rule): every
/// person gets the baseline, and a step more before sleep for each sign that sleep is slow to
/// come or comes at very different times. The numbers are `TollConfig.suggestion`'s.
public struct BufferSuggestion: Equatable, Sendable {
  public var before: Int
  public var after: Int
  /// Something in the person's own Health history moved it from the baseline.
  public var personal: Bool

  public init(_ estimate: SleepEstimate?, config: TollConfig = .defaults) {
    let rule = config.suggestion
    var before = rule.before
    if let latency = estimate?.latency, latency > rule.latencyOverMinutes {
      before += rule.latencyAdd
    }
    if let spread = estimate?.variability, spread > rule.variabilityOverMinutes {
      before += rule.variabilityAdd
    }
    self.before = min(before, rule.beforeMax)
    after = rule.after
    personal = self.before != rule.before
  }
}
