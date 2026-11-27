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
  /// means what it says, whichever side of midnight the times fall.
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
}

/// The buffers' targets at onboarding (#144): the recommended baseline, the same for everyone
/// (`TollConfig.suggestion`). Health's sleep fits the hours, not the buffers: nothing in it says
/// how long a person takes to fall asleep, and #145 personalises the buffers later from Dusk's own
/// nights.
public struct BufferSuggestion: Equatable, Sendable {
  public var before: Int
  public var after: Int

  public init(config: TollConfig = .defaults) {
    before = config.suggestion.before
    after = config.suggestion.after
  }
}
