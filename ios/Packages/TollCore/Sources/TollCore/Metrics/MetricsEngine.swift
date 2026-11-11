import Foundation

/// The numbers for one range (insights spec §2). `nil` percentages mean there was nothing to divide by.
public struct Metrics: Equatable, Sendable {
  public struct TagMetrics: Equatable, Sendable {
    public var passes = 0
    public var waitMinutes = 0

    public init(passes: Int = 0, waitMinutes: Int = 0) {
      self.passes = passes
      self.waitMinutes = waitMinutes
    }
  }

  public init() {}

  public var hits = 0
  public var passes = 0
  public var free = 0
  public var waited = 0
  public var held = 0
  public var abandoned = 0
  public var waitMinutes = 0
  public var cleanDays = 0
  public var activeDays = 0
  public var byTag: [Tag?: TagMetrics] = [:]
  public var byHour = [Int](repeating: 0, count: 24)
  public var byWeekday: [Weekday: Int] = [:]
  public var sessionChoices: [Int: Int] = [:]
  public var latePasses = 0

  public var heldPercent: Int? { hits == 0 ? nil : Int((Double(held) / Double(hits) * 100).rounded()) }
  public var lateShare: Double? { passes == 0 ? nil : Double(latePasses) / Double(passes) }
}

public struct DayMetrics: Equatable, Sendable {
  public var day: TollDay
  public var passes: Int
  public var active: Bool
  public var passList: [GateEvent]
}

/// Events in, every metric out, for any range (E8.36). Me insights and solo mode run entirely on this;
/// the server computes the same numbers for friends from the same rules.
public struct MetricsEngine: Sendable {
  public let math: DayMath
  public let config: TollConfig

  public init(math: DayMath, config: TollConfig) {
    self.math = math
    self.config = config
  }

  /// Metrics for the days `from` through `through`, inclusive. `events` may extend past the range: held
  /// looks a little past each hit.
  public func metrics(_ events: [GateEvent], from: TollDay, through: TollDay, tags: [AppRef: Tag] = [:]) -> Metrics {
    let sorted = Self.chronological(events)
    let window = TimeInterval(config.gate.resumeWindowSeconds)
    var cursor = DayCursor(math: math)
    var m = Metrics()
    var activeDays = Set<TollDay>()
    var passDays = Set<TollDay>()
    for (index, event) in sorted.enumerated() {
      let day = cursor.day(containing: event.occurredAt)
      guard day >= from, day <= through else { continue }
      activeDays.insert(day)
      switch event.kind {
      case .blockHit:
        m.hits += 1
        // In time order nothing past the resume window can change the answer, so the rest of the log is
        // never walked or copied for each hit.
        let deadline = event.occurredAt.addingTimeInterval(window)
        let following = sorted[(index + 1)...].prefix(while: { $0.occurredAt <= deadline })
        if GateRules.isHeld(hit: event, following: following, window: window) { m.held += 1 }
      case .pass:
        record(pass: event, day: day, tags: tags, into: &m)
        passDays.insert(day)
      case .waitAbandoned:
        m.abandoned += 1
      case .sessionEnded:
        if let minutes = event.sessionMinutes { m.sessionChoices[minutes, default: 0] += 1 }
      default:
        break
      }
    }
    m.activeDays = activeDays.count
    m.cleanDays = activeDays.subtracting(passDays).count
    return m
  }

  /// The store hands events over in time order already, so the usual call skips the sort.
  private static func chronological(_ events: [GateEvent]) -> [GateEvent] {
    var previous = Date.distantPast
    for event in events {
      if event.occurredAt < previous { return events.sorted { $0.occurredAt < $1.occurredAt } }
      previous = event.occurredAt
    }
    return events
  }

  private func record(pass event: GateEvent, day: TollDay, tags: [AppRef: Tag], into m: inout Metrics) {
    m.passes += 1
    let waitMinutes = event.free == true ? 0 : event.waitMinutes ?? 0
    if event.free == true { m.free += 1 } else { m.waited += 1 }
    m.waitMinutes += waitMinutes
    let tag = event.appRef.flatMap { tags[$0] }
    m.byTag[tag, default: Metrics.TagMetrics()].passes += 1
    m.byTag[tag, default: Metrics.TagMetrics()].waitMinutes += waitMinutes
    let hour = math.hour(of: event.occurredAt)
    m.byHour[hour] += 1
    m.byWeekday[day.weekday, default: 0] += 1
    if hour >= config.insights.lateStart || hour < config.gate.dayResetHour { m.latePasses += 1 }
  }

  /// One entry per day, in order, for day-by-day bars, the week strip and the term heatmap.
  public func days(_ events: [GateEvent], from: TollDay, through: TollDay) -> [DayMetrics] {
    var byDay: [TollDay: DayMetrics] = [:]
    var cursor = DayCursor(math: math)
    for event in events {
      let day = cursor.day(containing: event.occurredAt)
      guard day >= from, day <= through else { continue }
      // Taken out rather than copied, so the pass list has one owner while it grows.
      let blank = DayMetrics(day: day, passes: 0, active: false, passList: [])
      var entry = byDay.removeValue(forKey: day) ?? blank
      entry.active = true
      if event.kind == .pass {
        entry.passes += 1
        entry.passList.append(event)
      }
      byDay[day] = entry
    }
    let count = max(0, from.days(until: through) + 1)
    return (0..<count).map { offset in
      let day = from.adding(days: offset)
      return byDay[day] ?? DayMetrics(day: day, passes: 0, active: false, passList: [])
    }
  }

  /// This week ÷ last week − 1; nil when last week had no passes (spec §4 trend).
  public static func trend(this: Int, last: Int) -> Double? {
    last == 0 ? nil : Double(this) / Double(last) - 1
  }

  /// Average passes per weekday over the given weeks (I-4).
  public func weekdayAverages(_ events: [GateEvent], weeks: [TollDay]) -> [Weekday: Double] {
    guard let first = weeks.min(), let last = weeks.max() else { return [:] }
    let m = metrics(events, from: first, through: last.adding(days: 6))
    let n = Double(weeks.count)
    return Dictionary(uniqueKeysWithValues: Weekday.allCases.map { ($0, Double(m.byWeekday[$0] ?? 0) / n) })
  }

  /// Personalised status needs a history of daily pass counts on days blocks were on (spec §14).
  public func dailyHistory(_ events: [GateEvent], before day: TollDay, days count: Int) -> [Int] {
    days(events, from: day.adding(days: -count), through: day.adding(days: -1)).filter(\.active).map(\.passes)
  }
}

/// Events mostly share a Toll day with the one before them, so the last day's bounds answer most
/// lookups without asking the calendar again.
private struct DayCursor {
  let math: DayMath
  private var current: TollDay?
  private var start = Date.distantPast
  private var end = Date.distantPast

  init(math: DayMath) {
    self.math = math
  }

  mutating func day(containing date: Date) -> TollDay {
    if let current, date >= start, date < end { return current }
    let found = math.day(containing: date)
    let foundStart = math.start(of: found)
    let foundEnd = math.end(of: found)
    // The bounds stand in for the calendar only on a day the clock runs straight through. Around a
    // clock change (or a zone skipping a date) local hours can repeat or vanish inside them, so those
    // days ask the calendar for every event, as before.
    let change = math.calendar.timeZone.nextDaylightSavingTimeTransition(after: foundStart)
    let runsStraight = change.map { $0 >= foundEnd } ?? true
    if runsStraight, foundStart <= date, date < foundEnd {
      current = found
      start = foundStart
      end = foundEnd
    } else {
      current = nil
    }
    return found
  }
}
