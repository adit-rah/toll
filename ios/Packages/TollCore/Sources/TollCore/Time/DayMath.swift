import Foundation

/// Maps instants to Toll days and weeks in one time zone. Day = reset hour to reset hour; week starts
/// Monday at the reset hour (spec §4).
public struct DayMath: Sendable {
  public let calendar: Calendar
  public let resetHour: Int

  public init(timeZone: TimeZone, resetHour: Int) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    self.calendar = calendar
    self.resetHour = resetHour
  }

  public func day(containing date: Date) -> TollDay {
    let c = calendar.dateComponents([.year, .month, .day, .hour], from: date)
    let civil = TollDay(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    // Comparing the local hour (not subtracting hours) keeps DST days correct.
    return (c.hour ?? 0) < resetHour ? civil.adding(days: -1) : civil
  }

  public func start(of day: TollDay) -> Date {
    let components = DateComponents(year: day.year, month: day.month, day: day.day, hour: resetHour)
    return calendar.date(from: components) ?? .distantPast
  }

  public func end(of day: TollDay) -> Date { start(of: day.adding(days: 1)) }

  public func week(containing date: Date) -> TollDay { day(containing: date).weekStart }

  public func days(ofWeek weekStart: TollDay) -> [TollDay] {
    (0..<7).map { weekStart.adding(days: $0) }
  }

  /// The local hour 0–23 an instant falls in, for hour histograms.
  public func hour(of date: Date) -> Int { calendar.component(.hour, from: date) }

  public func weekday(of date: Date) -> Weekday {
    Weekday(gregorian: calendar.component(.weekday, from: date))
  }

  public func minuteOfDay(of date: Date) -> Int {
    let c = calendar.dateComponents([.hour, .minute], from: date)
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
  }
}
