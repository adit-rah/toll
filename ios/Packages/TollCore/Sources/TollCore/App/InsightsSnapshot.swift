import Foundation

/// Your sleep over a range (the design canvas): the hours the night kept its apps locked and the
/// "Never mind" taps by hour of the night. Read from the ended nights (`PastNight.merged`), so 30 days
/// and All time count every night the night log kept, not the ten or so the transition log holds
/// (the audit). Only the night's block counts; Study's hours aren't sleep. Pure and tested.
public struct InsightsSnapshot: Equatable, Sendable {
  public enum Range: String, CaseIterable, Sendable {
    case week, month, all

    var days: Int? {
      switch self {
      case .week: 7
      case .month: 30
      case .all: nil
      }
    }
  }

  /// The chart's hours: from the hour the earliest night starts to the hour the latest ends in, so
  /// a 12:30 – 8:30 am night keeps its last hours (the audit).
  public struct NightHours: Equatable, Sendable {
    /// The first bar's hour on the clock (22 is 10 pm).
    public var first: Int
    public var count: Int

    public static let standard = NightHours(first: 22, count: 9)

    init(first: Int, count: Int) {
      self.first = first
      self.count = count
    }

    public init(_ schedule: WeeklySchedule?) {
      let windows = schedule?.windows.filter(\.isValid) ?? []
      // Minutes since noon, so a night that crosses midnight is one span.
      let starts = windows.map { ($0.start.minuteOfDay - 720 + 1440) % 1440 }
      let ends = windows.map { ($0.start.minuteOfDay - 720 + 1440) % 1440 + $0.minutes }
      guard let start = starts.min(), let end = ends.max() else {
        self = .standard
        return
      }
      let from = start / 60
      self.init(first: (from + 12) % 24, count: min(24, (end - 1) / 60 - from + 1))
    }

    /// The bar a moment falls in, if it's inside the night's hours.
    func index(of hour: Int) -> Int? {
      let index = (hour - first + 24) % 24
      return index < count ? index : nil
    }

    /// The clock hour of the last bar.
    public var last: Int { (first + count - 1) % 24 }
  }

  /// Nights the block ran in the range.
  public var nights: Int
  public var hoursBlocked: Int
  /// Taps by hour of the night; index 0 is `hours.first`.
  public var byHour: [Int]
  public var hours: NightHours
  public var peakHour: Int?
  public var taps: Int

  public init(
    nights past: [PastNight], hours: NightHours = .standard, now: Date, calendar: Calendar,
    range: Range
  ) {
    let tonight = calendar.startOfDay(for: now.addingTimeInterval(-12 * 3600))
    let from = range.days.flatMap { calendar.date(byAdding: .day, value: -$0, to: tonight) }
    let inRange = past.filter { night in from.map { night.night > $0 } ?? true }
    nights = inRange.filter(\.ran).count
    hoursBlocked = Int(inRange.map(\.lockedTime).reduce(0, +) / 3600)
    self.hours = hours

    var byHour = Array(repeating: 0, count: hours.count)
    for tap in inRange.flatMap({ $0.taps ?? [] }) {
      if let index = hours.index(of: calendar.component(.hour, from: tap)) { byHour[index] += 1 }
    }
    self.byHour = byHour
    taps = byHour.reduce(0, +)
    let top = byHour.max() ?? 0
    peakHour = top > 0 ? byHour.firstIndex(of: top).map { (hours.first + $0) % 24 } : nil
  }

  public var isEmpty: Bool { nights == 0 && taps == 0 }
}
