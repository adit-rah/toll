import Foundation

/// A night as setup and Blocks draw it (D68, #76): moon, start – end, sun, over a strip of the night
/// alone, so the wake wheel visibly moves the night and Ready shows tonight without words. Tonight's
/// strip is the whole day (D75); this one stays on the night.
public struct NightPicture: Equatable, Sendable {
  /// The night on a strip of the evening and morning around it, as fractions.
  public struct Strip: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
      /// Drawn as an outline: still to come.
      case upcoming
      /// Solid: on now.
      case on
      /// Dashed: nothing will block.
      case off
    }

    public var start: Double
    public var end: Double
    /// Where the lock starts, the gap before bed (D76); nil with no gap.
    public var lock: Double?
    public var phase: Phase
    public var label: String
    /// Five hour labels, evenly spaced from the strip's start to its end ("6 pm" … "10 am").
    public var hours: [String] = []
  }

  public var start: String
  public var end: String
  /// "8 h 30 m".
  public var length: String
  /// No "now" on it: the strip stays put while the wheel turns, and only the night moves.
  public var timeline: Strip

  /// The night on at `now`, or the next one the schedule holds. `gap` draws the lock before bed
  /// (D76); the times stay bed to wake.
  public init?(_ schedule: WeeklySchedule, gap: Int = 0, now: Date, calendar: Calendar) {
    guard
      let night = schedule.occurrence(containing: now, calendar: calendar)
        ?? schedule.nextStart(after: now, calendar: calendar).flatMap({
          schedule.occurrence(containing: $0, calendar: calendar)
        })
    else { return nil }
    // Measured from the night itself, so the strip is the boards' 6 pm → 10 am whenever it fits.
    let (spanStart, step) = Self.span(night: night, now: night.start, calendar: calendar)
    let span = TimeInterval(step * 4 * 3600)
    func fraction(_ date: Date) -> Double {
      min(1, max(0, date.timeIntervalSince(spanStart) / span))
    }
    start = Copy.time(night.start, in: calendar)
    end = Copy.time(night.end, in: calendar)
    length = Copy.length(minutes: Int(night.end.timeIntervalSince(night.start) / 60))
    let lock = night.start.addingTimeInterval(-TimeInterval(gap * 60))
    let label = Copy.Setup.nightLabel(start: start, end: end)
    timeline = Strip(
      start: fraction(night.start), end: fraction(night.end),
      lock: gap > 0 ? fraction(lock) : nil, phase: .upcoming,
      label: gap > 0
        ? label + ", " + Copy.Gap.locksAt(Copy.time(lock, in: calendar)) : label,
      hours: (0...4).map {
        Copy.time(
          spanStart.addingTimeInterval(TimeInterval($0 * step * 3600)), in: calendar, short: true)
      })
  }

  /// The strip's start and its label step in hours (the strip is four steps long). The boards'
  /// 6 pm → 10 am (4 h steps) when the night fits in it and now is in it or the afternoon before;
  /// otherwise whole hours from an hour before the earlier of now and the start to an hour after the
  /// end, widened to four equal steps (#82).
  static func span(night: TimeWindow.Night, now: Date, calendar: Calendar) -> (Date, Int) {
    let evening = calendar.startOfDay(for: night.start.addingTimeInterval(-12 * 3600))
    if let six = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: evening) {
      let end = six.addingTimeInterval(16 * 3600)
      if night.start >= six, night.end <= end, now <= end,
        now >= six.addingTimeInterval(-6 * 3600)
      {
        return (six, 4)
      }
    }
    func hourFloor(_ date: Date) -> Date {
      calendar.dateInterval(of: .hour, for: date)?.start ?? date
    }
    let start = hourFloor(min(now, night.start)).addingTimeInterval(-3600)
    let end = night.end.addingTimeInterval(3600)
    let hours = Int((end.timeIntervalSince(start) / 3600).rounded(.up))
    // Never wider than a day: past that, now sits at the left edge.
    let step = min(6, max(2, Int((Double(hours) / 4).rounded(.up))))
    return (max(start, end.addingTimeInterval(-TimeInterval(step * 4 * 3600))), step)
  }
}
