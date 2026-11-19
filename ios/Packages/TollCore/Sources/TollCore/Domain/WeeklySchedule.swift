import Foundation

/// When a block is on: rules, each a set of days and one window that starts on those days (D29). The
/// Sleep block with different weekends is two rules; a block every day is one.
public struct WeeklySchedule: Codable, Hashable, Sendable {
  public struct Rule: Codable, Hashable, Sendable {
    public var days: Set<Weekday>
    public var window: TimeWindow

    public init(days: Set<Weekday>, window: TimeWindow) {
      self.days = days
      self.window = window
    }
  }

  public var rules: [Rule]

  public init(rules: [Rule]) {
    self.rules = rules
  }

  public static func everyDay(_ window: TimeWindow) -> WeeklySchedule {
    WeeklySchedule(rules: [Rule(days: Weekday.all, window: window)])
  }

  public var windows: [TimeWindow] { rules.map(\.window) }
  public var isValid: Bool {
    !rules.isEmpty && rules.allSatisfy { $0.window.isValid && !$0.days.isEmpty }
  }

  /// Every occurrence that starts on the calendar days `from` to `through` around `date`.
  func occurrences(around date: Date, offsets: ClosedRange<Int>, calendar: Calendar)
    -> [TimeWindow.Night]
  {
    var result: [TimeWindow.Night] = []
    for offset in offsets {
      guard let day = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
      let weekday = Weekday(of: day, calendar: calendar)
      for rule in rules where rule.days.contains(weekday) {
        if let night = rule.window.night(startingOn: day, calendar: calendar) {
          result.append(night)
        }
      }
    }
    return result
  }

  public func occurrence(containing date: Date, calendar: Calendar) -> TimeWindow.Night? {
    occurrences(around: date, offsets: -1...0, calendar: calendar).filter { $0.contains(date) }
      .max { $0.start < $1.start }
  }

  public func lastEnd(atOrBefore date: Date, calendar: Calendar) -> Date? {
    occurrences(around: date, offsets: -8...0, calendar: calendar).map(\.end).filter { $0 <= date }
      .max()
  }

  public func nextStart(after date: Date, calendar: Calendar) -> Date? {
    occurrences(around: date, offsets: 0...8, calendar: calendar).map(\.start).filter { $0 > date }
      .min()
  }

  /// Every occurrence end in (`start`, `end`], oldest first.
  public func ends(after start: Date, through end: Date, calendar: Calendar) -> [Date] {
    guard start < end else { return [] }
    let days = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    return occurrences(around: start, offsets: -1...days, calendar: calendar).map(\.end)
      .filter { $0 > start && $0 <= end }.sorted()
  }
}
