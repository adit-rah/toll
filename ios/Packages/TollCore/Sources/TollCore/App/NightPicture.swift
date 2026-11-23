import Foundation

/// A night as setup draws it (D68, #76): moon, start – end, sun, over the same strip Tonight shows,
/// so the wake wheel visibly moves the night and Ready shows tonight without words.
public struct NightPicture: Equatable, Sendable {
  public var start: String
  public var end: String
  /// "8 h 30 m".
  public var length: String
  /// No "now" on it: the strip stays put while the wheel turns, and only the night moves.
  public var timeline: HomeSnapshot.Timeline

  /// The night on at `now`, or the next one the schedule holds.
  public init?(_ schedule: WeeklySchedule, now: Date, calendar: Calendar) {
    guard
      let night = schedule.occurrence(containing: now, calendar: calendar)
        ?? schedule.nextStart(after: now, calendar: calendar).flatMap({
          schedule.occurrence(containing: $0, calendar: calendar)
        })
    else { return nil }
    // Measured from the night itself, so the strip is the boards' 6 pm → 10 am whenever it fits.
    let (spanStart, step) = HomeSnapshot.span(night: night, now: night.start, calendar: calendar)
    let span = TimeInterval(step * 4 * 3600)
    func fraction(_ date: Date) -> Double {
      min(1, max(0, date.timeIntervalSince(spanStart) / span))
    }
    start = Copy.time(night.start, in: calendar)
    end = Copy.time(night.end, in: calendar)
    length = Copy.length(minutes: Int(night.end.timeIntervalSince(night.start) / 60))
    timeline = HomeSnapshot.Timeline(
      start: fraction(night.start), end: fraction(night.end), now: nil, nowInside: false,
      phase: .upcoming, label: Copy.Setup.nightLabel(start: start, end: end),
      hours: (0...4).map {
        Copy.time(
          spanStart.addingTimeInterval(TimeInterval($0 * step * 3600)), in: calendar, short: true)
      })
  }
}
