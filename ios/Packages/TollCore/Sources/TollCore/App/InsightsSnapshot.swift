import Foundation

/// Insights from the transition log (the design canvas): nights with a block on, hours blocked, taps on
/// the block screen by week and by hour. Pure and tested; the view lays it out.
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

  public var nights: Int
  public var since: Date?
  public var hoursBlocked: Int
  /// Taps on the block screen per week, oldest first, at most the last four.
  public var weeks: [Int]
  /// Change from the first week to the last, in percent; nil with fewer than two weeks.
  public var change: Int?
  /// Taps by hour of the night, 10 pm to 6 am (index 0 is 10 pm).
  public var byHour: [Int]
  public var peakHour: Int?

  public init(log: [Transition], now: Date, calendar: Calendar, range: Range) {
    let from = range.days.flatMap { calendar.date(byAdding: .day, value: -$0, to: now) }
    let lines = log.filter { line in from.map { line.at >= $0 } ?? true }.sorted { $0.at < $1.at }
    func night(_ date: Date) -> Date {
      calendar.startOfDay(for: date.addingTimeInterval(-12 * 3600))
    }

    let onNights = Set(lines.filter { $0.blockOn && $0.changed }.map { night($0.at) })
    nights = onNights.count
    since = onNights.min()

    var seconds: TimeInterval = 0
    var onSince: Date?
    for line in lines where line.changed {
      if line.blockOn, onSince == nil { onSince = line.at }
      if !line.blockOn, let start = onSince {
        seconds += line.at.timeIntervalSince(start)
        onSince = nil
      }
    }
    if let start = onSince { seconds += now.timeIntervalSince(start) }
    hoursBlocked = Int(seconds / 3600)

    let taps = lines.filter { $0.cause == .blockScreen }
    if let first = onNights.min() ?? taps.first.map({ night($0.at) }) {
      // Whole weeks only, so a week that has just begun cannot read as a drop; before the first whole
      // week, the one so far.
      let count = max(
        1, (calendar.dateComponents([.day], from: first, to: night(now)).day ?? 0) / 7)
      var weeks = Array(repeating: 0, count: count)
      for tap in taps {
        let index = (calendar.dateComponents([.day], from: first, to: night(tap.at)).day ?? 0) / 7
        if weeks.indices.contains(index) { weeks[index] += 1 }
      }
      self.weeks = Array(weeks.suffix(4))
    } else {
      weeks = []
    }
    if weeks.count >= 2, let first = weeks.first, first > 0, let last = weeks.last {
      change = Int(((Double(last) - Double(first)) / Double(first) * 100).rounded())
    } else {
      change = nil
    }

    var byHour = Array(repeating: 0, count: 9)
    for tap in taps {
      let hour = calendar.component(.hour, from: tap.at)
      let index = (hour - 22 + 24) % 24
      if index < byHour.count { byHour[index] += 1 }
    }
    self.byHour = byHour
    let top = byHour.max() ?? 0
    peakHour = top > 0 ? byHour.firstIndex(of: top).map { ($0 + 22) % 24 } : nil
  }

  public var isEmpty: Bool { nights == 0 && weeks.allSatisfy { $0 == 0 } }
}
