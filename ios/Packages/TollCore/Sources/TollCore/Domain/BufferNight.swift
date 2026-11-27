import Foundation

/// One night as the buffer suggestion reads it, from the night log (#145): the buffers it had,
/// where its pauses were asked, and, once Health has the night, how long after planned sleep the
/// person fell asleep.
public struct BufferNight: Equatable, Sendable {
  /// The night's key: the day it starts, noon to noon.
  public var night: Date
  public var ran: Bool
  public var before: Int
  public var after: Int
  /// Pauses asked in each buffer; nil in records from before they were kept, whose weeks are left
  /// out rather than read as calm.
  public var pausesBefore: Int?
  public var pausesAfter: Int?
  public var screenTimeOff: Bool
  /// Health's sleep onset minus planned sleep, in minutes; nil without Health's night.
  public var late: Int?

  public init(
    night: Date, ran: Bool, before: Int, after: Int, pausesBefore: Int?, pausesAfter: Int?,
    screenTimeOff: Bool, late: Int? = nil
  ) {
    self.night = night
    self.ran = ran
    self.before = before
    self.after = after
    self.pausesBefore = pausesBefore
    self.pausesAfter = pausesAfter
    self.screenTimeOff = screenTimeOff
    self.late = late
  }
}

extension BufferSuggestion {
  /// Fitted from the night log's nights: each side's ended weeks, judged as Monday's rule judges
  /// them, and Health's sleep over the same weeks.
  public init(
    nights: [BufferNight], now: Date, calendar: Calendar, config: TollConfig = .defaults
  ) {
    let current = UnlockSupply.week(containing: now, calendar: calendar, config: config)
    let from =
      calendar.date(byAdding: .day, value: -7 * config.suggestion.lookbackWeeks, to: current)
      ?? current
    let recent = nights.filter {
      (from..<current).contains(Self.week(of: $0.night, calendar, config))
    }
    self.init(
      before: Self.weeks(.before, recent, calendar: calendar, config: config),
      after: Self.weeks(.after, recent, calendar: calendar, config: config),
      lateOnset: Self.lateOnset(recent, config: config), config: config)
  }

  /// The pauses' week (D70) a night belongs to: Monday's night starts one.
  static func week(of night: Date, _ calendar: Calendar, _ config: TollConfig) -> Date {
    let noon = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: night) ?? night
    return UnlockSupply.week(containing: noon, calendar: calendar, config: config)
  }

  /// One side's weeks, oldest first. A week counts only when every night the lock ran says where
  /// its pauses were asked; its buffer is the one most of those nights had, the later on a tie.
  static func weeks(
    _ side: Gap.Side, _ nights: [BufferNight], calendar: Calendar, config: TollConfig
  ) -> [BufferWeek] {
    let byWeek = Dictionary(grouping: nights) { week(of: $0.night, calendar, config) }
    return byWeek.keys.sorted().compactMap { key in
      let group = (byWeek[key] ?? []).sorted { $0.night < $1.night }
      let ran = group.filter(\.ran)
      let pauses = ran.map { side == .before ? $0.pausesBefore : $0.pausesAfter }
      guard !ran.isEmpty, !pauses.contains(nil) else { return nil }
      var count: [Int: Int] = [:]
      var minutes = 0
      for night in ran {
        let value = side == .before ? night.before : night.after
        count[value, default: 0] += 1
        if count[value, default: 0] >= count[minutes, default: 0] { minutes = value }
      }
      var tally = Gap.Tally(week: key)
      tally.nights = Set(ran.map(\.night))
      tally.pausesInGap = pauses.compactMap { $0 }.reduce(0, +)
      tally.screenTimeOff = group.contains(where: \.screenTimeOff)
      return BufferWeek(
        minutes: minutes, verdict: Gap.verdict(tally, config), pauses: tally.pausesInGap)
    }
  }

  /// Health's sleep comes well after planned sleep on most nights the lock ran: the median of
  /// enough nights at `suggestion.lateOnsetMinutes` or more.
  static func lateOnset(_ nights: [BufferNight], config: TollConfig) -> Bool {
    lateOnset(nights.filter(\.ran).compactMap(\.late), config: config)
  }

  static func lateOnset(_ late: [Int], config: TollConfig) -> Bool {
    let rule = config.suggestion
    guard late.count >= rule.healthNights, !late.isEmpty else { return false }
    let sorted = late.sorted()
    let middle = sorted.count / 2
    let doubled =
      sorted.count % 2 == 1 ? 2 * sorted[middle] : sorted[middle - 1] + sorted[middle]
    return doubled >= 2 * rule.lateOnsetMinutes
  }
}
