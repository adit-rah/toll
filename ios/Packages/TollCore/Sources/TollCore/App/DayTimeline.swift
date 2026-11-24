import Foundation

/// Tonight's strip (D75): a whole day, from the night's end to the same time the next day, so the
/// night is never split and the day's blocks fit before it. The night is drawn as the night; every
/// other block's hours inside the day are drawn apart from it, and a tap on any of them opens a
/// snippet of that block.
public struct DayTimeline: Equatable, Sendable {
  /// One occurrence of a block inside the day.
  public struct Segment: Equatable, Sendable, Identifiable {
    public enum State: Equatable, Sendable {
      case on, paused, later, ended, off
      /// Waiting for Always location (#63).
      case waiting
      /// In its hours, away from its place.
      case away
    }

    /// How it's drawn: solid while on, outlined before, faint once over, dashed when nothing will
    /// block.
    public enum Phase: Equatable, Sendable {
      case on, later, ended, off
    }

    /// Where it runs, for the snippet's glyph.
    public enum Place: Equatable, Sendable {
      case home, place, anywhere, needsAlways
    }

    public var id: String
    public var block: BlockID
    public var kind: Block.Kind
    /// Fractions of the day; an occurrence running past an edge is cut there.
    public var start: Double
    public var end: Double
    public var state: State
    /// "Your night", or the block's name.
    public var title: String
    /// "10:30 pm – 7:00 am", the whole occurrence even where the strip cuts it.
    public var hours: String
    /// "4 apps".
    public var apps: String
    /// "Home", "Robarts Library", "Anywhere".
    public var place: String
    public var placeKind: Place
    /// "On now", "Tonight", "Later today", "Tomorrow", "Ended"…
    public var stateText: String

    public var isNight: Bool { kind == .sleep }

    public var phase: Phase {
      switch state {
      case .on, .paused: .on
      case .later, .waiting, .away: .later
      case .ended: .ended
      case .off: .off
      }
    }

    /// The snippet in one line, for VoiceOver: "Your night, 10:30 pm – 7:00 am, 4 apps, Home,
    /// Tonight".
    public var spoken: String {
      [title, hours, apps, place, stateText].joined(separator: ", ")
    }
  }

  /// An hour label and where it sits.
  public struct Hour: Equatable, Sendable {
    public var at: Double
    public var label: String
  }

  public var start: Date
  public var end: Date
  public var segments: [Segment]
  /// Where now is; always inside the day.
  public var now: Double
  /// "Now, 7:55 pm", for VoiceOver.
  public var nowLabel: String
  /// Every six hours on the clock (12 am, 6 am, 12 pm, 6 pm), none hard against an edge.
  public var hours: [Hour]
  /// Over the strip's end, where the night is: "Tonight 10:30 pm" under the morning card (HomeSnapshot).
  public var label: String?

  /// `blocking` is false when nothing can block: the free week over, or Screen Time off (#45).
  public init(state: DuskState, now: Date, calendar: Calendar, blocking: Bool = true) {
    let (start, end) = Self.axis(state.sleepBlock, now: now, calendar: calendar)
    self.start = start
    self.end = end
    let length = max(1, end.timeIntervalSince(start))
    func fraction(_ date: Date) -> Double { min(1, max(0, date.timeIntervalSince(start) / length)) }
    self.now = fraction(now)
    nowLabel = Copy.Strip.now(Copy.time(now, in: calendar))
    var segments: [Segment] = []
    for block in state.blocks where block.isSleep || block.isOn {
      let occurrences = block.schedule.occurrences(
        around: start, offsets: -1...2, calendar: calendar
      )
      .filter { $0.end > start && $0.start < end }
      for occurrence in Set(occurrences).sorted(by: { $0.start < $1.start }) {
        segments.append(
          Self.segment(
            block, occurrence, state: state, now: now, calendar: calendar, blocking: blocking,
            fraction: fraction))
      }
    }
    self.segments = segments.sorted { $0.start < $1.start }
    hours = Self.hours(from: start, to: end, calendar: calendar, fraction: fraction)
  }

  /// The day the strip covers. While a night is on, or the next one ends within a day, it ends at
  /// that night's end. Otherwise it starts at the last night's end, so a night more than a day away
  /// (a weekday night seen on a Friday) leaves the strip to today; with no night before either, it
  /// keeps the next night's wake time. With no night at all, midnight to midnight.
  static func axis(_ sleep: Block?, now: Date, calendar: Calendar) -> (Date, Date) {
    func shift(_ date: Date, _ days: Int) -> Date {
      calendar.date(byAdding: .day, value: days, to: date)
        ?? date.addingTimeInterval(TimeInterval(days) * 86_400)
    }
    if let schedule = sleep?.schedule {
      if let night = schedule.occurrence(containing: now, calendar: calendar) {
        return (shift(night.end, -1), night.end)
      }
      let next = schedule.nextStart(after: now, calendar: calendar).flatMap {
        schedule.occurrence(containing: $0, calendar: calendar)
      }
      if let next, shift(next.end, -1) <= now { return (shift(next.end, -1), next.end) }
      if let last = schedule.lastEnd(atOrBefore: now, calendar: calendar), shift(last, 1) > now {
        return (last, shift(last, 1))
      }
      if var end = next?.end {
        while shift(end, -1) > now { end = shift(end, -1) }
        return (shift(end, -1), end)
      }
    }
    let midnight = calendar.startOfDay(for: now)
    return (midnight, shift(midnight, 1))
  }

  static func segment(
    _ block: Block, _ occurrence: TimeWindow.Night, state: DuskState, now: Date,
    calendar: Calendar, blocking: Bool, fraction: (Date) -> Double
  ) -> Segment {
    let segmentState = Self.state(block, occurrence, state: state, now: now, blocking: blocking)
    let placeText = BlocksSnapshot.placeText(block, state: state)
    let placeKind: Segment.Place =
      Engine.waitsForAlways(block, state)
      ? .needsAlways
      : placeText == nil || state.location == .scheduleOnly
        ? .anywhere
        : block.place == state.sleepBlock?.place ? .home : .place
    func clock(_ date: Date) -> ClockTime {
      ClockTime(
        hour: calendar.component(.hour, from: date), minute: calendar.component(.minute, from: date)
      )
    }
    return Segment(
      id: "\(block.id.raw)@\(Int(occurrence.start.timeIntervalSinceReferenceDate))",
      block: block.id, kind: block.kind, start: fraction(occurrence.start),
      end: fraction(occurrence.end), state: segmentState,
      title: block.isSleep ? Copy.Strip.yourNight : block.name,
      hours: Copy.span(
        TimeWindow(start: clock(occurrence.start), end: clock(occurrence.end)), in: calendar,
        short: true),
      apps: Copy.Blocks.summary(categories: block.categoryCount, apps: block.appCount),
      place: placeText ?? Copy.Blocks.anywhere, placeKind: placeKind,
      stateText: Self.text(segmentState, block, occurrence, placeKind, now: now, calendar: calendar)
    )
  }

  static func state(
    _ block: Block, _ occurrence: TimeWindow.Night, state: DuskState, now: Date, blocking: Bool
  ) -> Segment.State {
    if !block.isOn || !state.trial.entitled || !blocking { return .off }
    if occurrence.end <= now { return .ended }
    if occurrence.start > now { return .later }
    if state.runtime.active[block.id] != nil {
      return state.door?.phase == .open ? .paused : .on
    }
    if Engine.waitsForAlways(block, state) { return .waiting }
    return block.place != nil && state.location == .places ? .away : .later
  }

  static func text(
    _ state: Segment.State, _ block: Block, _ occurrence: TimeWindow.Night,
    _ place: Segment.Place, now: Date, calendar: Calendar
  ) -> String {
    switch state {
    case .on: Copy.Strip.onNow
    case .paused: Copy.Strip.paused
    case .ended: Copy.Strip.ended
    case .off: Copy.Strip.off
    case .waiting: Copy.Strip.waiting
    case .away: place == .home ? Copy.Strip.whenHome : Copy.Strip.whenThere
    case .later:
      block.isSleep
        ? Copy.Strip.tonight
        : calendar.isDate(occurrence.start, inSameDayAs: now)
          ? Copy.Strip.laterToday : Copy.Strip.tomorrow
    }
  }

  static func hours(
    from start: Date, to end: Date, calendar: Calendar, fraction: (Date) -> Double
  ) -> [Hour] {
    // An hour and a half from each edge, so a label never runs off the strip.
    let margin = 1.5 / 24
    guard var hour = calendar.dateInterval(of: .hour, for: start)?.start else { return [] }
    var result: [Hour] = []
    while hour <= end {
      let at = fraction(hour)
      if calendar.component(.hour, from: hour) % 6 == 0, at >= margin, at <= 1 - margin {
        result.append(Hour(at: at, label: Copy.time(hour, in: calendar, short: true)))
      }
      guard let next = calendar.date(byAdding: .hour, value: 1, to: hour) else { break }
      hour = next
    }
    return result
  }
}
