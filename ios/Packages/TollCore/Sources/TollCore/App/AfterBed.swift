import Foundation

/// Apple's own count of screen time after bed (#65, D46). Only a DeviceActivityReport extension can
/// sum it, and it draws the number inside Dusk's window: the app can't read it, so it is never
/// compared with Dusk's numbers or used in a rule. Here is only what the app asks for.
public enum AfterBed {
  /// The report the extension draws and the app asks for, by name; the two must match.
  public static let context = "afterBed"

  /// Last night's sleep, bed to wake (the night's stored hours, without the buffers around it), for
  /// the night that ended most recently. Nil before setup, before a first night has ended, and for a
  /// night with no hours.
  public static func lastNight(_ state: DuskState, now: Date, calendar: Calendar) -> DateInterval? {
    guard let setup = state.setupFinishedAt, let sleep = state.sleepBlock else { return nil }
    let night = sleep.schedule.occurrences(around: now, offsets: -8...0, calendar: calendar)
      .filter { $0.end <= now && $0.end > setup }
      .max { $0.end < $1.end }
    return night.map { DateInterval(start: max($0.start, setup), end: $0.end) }
  }

  /// The minutes Apple counted, as the report shows them and as VoiceOver says them.
  public static func shown(_ seconds: TimeInterval) -> (text: String, spoken: String) {
    let minutes = max(0, Int(seconds / 60))
    return (Copy.Home.duration(seconds), Copy.AfterBed.minutes(minutes))
  }
}
