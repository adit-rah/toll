import Foundation

extension NightRecordLine {
  /// The night and whether the block ran, read back from one line; nil for a line it can't read.
  static func past(_ line: Data, calendar: Calendar) -> PastNight? {
    guard let record = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
      let night = record["night"] as? String
    else { return nil }
    let day = DateFormatter()
    day.calendar = calendar
    day.timeZone = calendar.timeZone
    day.locale = Locale(identifier: "en_US_POSIX")
    day.dateFormat = "yyyy-MM-dd"
    guard let date = day.date(from: night) else { return nil }
    let ran =
      (record["dusk"] as? [String: Any])?["ran"] as? Bool ?? (record["block_start"] is String)
    return PastNight(night: calendar.startOfDay(for: date), ran: ran)
  }
}

extension NightLog {
  /// Every recorded night, oldest first, for Your sleep's counts (#103).
  public func past(calendar: Calendar) -> [PastNight] {
    lines().compactMap { NightRecordLine.past($0, calendar: calendar) }
  }
}
