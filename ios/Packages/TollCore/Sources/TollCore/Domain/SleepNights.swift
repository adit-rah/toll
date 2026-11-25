import Foundation

/// One stretch of sleep as Apple Health stores it (`sleepAnalysis`), mapped by the Health adapter
/// (#144). Dusk only reads; it never writes to Health.
public struct SleepSample: Hashable, Sendable {
  public enum Kind: String, Hashable, Sendable {
    case inBed, asleep, awake
  }

  /// What wrote it: a watch measures sleep; a phone or another app may only guess it.
  public enum Source: String, Hashable, Sendable {
    case watch, phone, other
  }

  public var start: Date
  public var end: Date
  public var kind: Kind
  public var source: Source
  /// The writing app or device, so overlapping sources aren't counted twice.
  public var sourceID: String

  public init(start: Date, end: Date, kind: Kind, source: Source, sourceID: String) {
    self.start = start
    self.end = end
    self.kind = kind
    self.source = source
    self.sourceID = sourceID
  }
}

/// One night's sleep from Health: when sleep began and ended, and how long asleep and awake.
public struct SleepNight: Equatable, Sendable {
  /// The night's key, noon to noon, as the night log keys it.
  public var night: Date
  public var onset: Date
  public var wake: Date
  public var asleepMinutes: Int
  public var awakeMinutes: Int
  public var source: SleepSample.Source

  /// Fri and Sat nights, as "Different on weekends" splits them.
  public func weekend(_ calendar: Calendar) -> Bool {
    Weekday.weekendNights.contains(Weekday(of: night, calendar: calendar))
  }

  /// Every night in the samples, oldest first. Overlapping sources are merged by taking one per
  /// night: a watch if one measured it, otherwise the one with the most sleep. Samples that start
  /// between `nightEndHour` and `nightStartHour` are naps, not a night.
  public static func from(
    _ samples: [SleepSample], calendar: Calendar, config: TollConfig = .defaults
  ) -> [SleepNight] {
    let health = config.health
    let night = samples.filter { sample in
      let hour = calendar.component(.hour, from: sample.start)
      return (hour >= health.nightStartHour || hour < health.nightEndHour)
        && sample.end > sample.start
    }
    let byNight = Dictionary(grouping: night) {
      calendar.startOfDay(for: $0.start.addingTimeInterval(-12 * 3600))
    }
    return byNight.compactMap { key, samples in
      let asleep = samples.filter { $0.kind == .asleep }
      guard let chosen = source(asleep) else { return nil }
      let mine = asleep.filter { $0.sourceID == chosen }
      guard let onset = mine.map(\.start).min(), let wake = mine.map(\.end).max() else {
        return nil
      }
      let awake = samples.filter { $0.kind == .awake && $0.sourceID == chosen }
      return SleepNight(
        night: key, onset: onset, wake: wake, asleepMinutes: minutes(mine),
        awakeMinutes: minutes(awake), source: mine.first?.source ?? .other)
    }
    .sorted { $0.night < $1.night }
  }

  /// The source whose sleep counts tonight: a watch's if any, else the one with the most.
  static func source(_ asleep: [SleepSample]) -> String? {
    let ids = Set(asleep.map(\.sourceID)).sorted()
    if let watch = ids.first(where: { id in
      asleep.contains { $0.sourceID == id && $0.source == .watch }
    }) {
      return watch
    }
    return ids.max { a, b in
      minutes(asleep.filter { $0.sourceID == a }) < minutes(asleep.filter { $0.sourceID == b })
    }
  }

  /// Total minutes, overlaps within one source counted once.
  static func minutes(_ samples: [SleepSample]) -> Int {
    var total: TimeInterval = 0
    var reached: Date?
    for sample in samples.sorted(by: { $0.start < $1.start }) {
      let from = max(sample.start, reached ?? sample.start)
      if sample.end > from { total += sample.end.timeIntervalSince(from) }
      reached = max(reached ?? sample.end, sample.end)
    }
    return Int(total / 60)
  }
}
