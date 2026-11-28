import Foundation

extension NightRecordLine {
  /// The night as Your sleep counts it, read back from one line; nil for a line it can't read.
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
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    func time(_ value: Any?) -> Date? { (value as? String).flatMap(iso.date(from:)) }
    let dusk = record["dusk"] as? [String: Any]
    // Health's sleep, from a correction (#144): all three or none.
    let slept = time(record["sleep_onset"]).flatMap { onset in
      time(record["wake"]).flatMap { wake in
        (record["asleep_min"] as? Int).map {
          PastNight.Slept(onset: onset, wake: wake, minutes: $0)
        }
      }
    }
    return PastNight(
      night: calendar.startOfDay(for: date),
      ran: dusk?["ran"] as? Bool ?? (record["block_start"] is String),
      start: time(record["block_start"]), end: time(record["block_end"]),
      locked: (dusk?["locked_min"] as? Int).map { TimeInterval($0 * 60) },
      taps: (dusk?["taps"] as? [Any])?.compactMap(time), slept: slept,
      lastReach: time(dusk?["last_reach"]), reaches: record["block_screens"] as? Int,
      pauses: record["unlocks_used"] as? Int)
  }
}

extension NightLog {
  /// Every recorded night, oldest first, each at its highest revision, for Your sleep's counts
  /// (#103).
  public func past(calendar: Calendar) -> [PastNight] {
    current().compactMap { NightRecordLine.past($0, calendar: calendar) }
  }

  /// Every recorded night as the buffer suggestion reads it, oldest first, each at its highest
  /// revision, so Health's correction brings its sleep (#145).
  public func buffers(calendar: Calendar) -> [BufferNight] {
    current().compactMap { NightRecordLine.buffers($0, calendar: calendar) }
  }
}

extension NightRecordLine {
  /// The night as the buffer suggestion reads it (#145), from one line; nil for a line it can't
  /// read. Records from before pauses were kept by buffer read as unknown, not as none.
  static func buffers(_ line: Data, calendar: Calendar) -> BufferNight? {
    guard let record = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
      let past = past(line, calendar: calendar)
    else { return nil }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    func time(_ value: Any?) -> Date? { (value as? String).flatMap(iso.date(from:)) }
    let dusk = record["dusk"] as? [String: Any]
    let bed = time(record["bed"]) ?? time(record["planned_bedtime"])
    let late = time(record["sleep_onset"]).flatMap { onset in
      bed.map { Int((onset.timeIntervalSince($0) / 60).rounded()) }
    }
    // The buffer the night ran with: personal timing's start moves it (D99).
    let before = max(
      0, (record["gap_min"] as? Int ?? 0) - (record["action_offset_min"] as? Int ?? 0))
    return BufferNight(
      night: past.night, ran: past.ran, before: before,
      after: record["after_min"] as? Int ?? 0, pausesBefore: dusk?["pauses_before"] as? Int,
      pausesAfter: dusk?["pauses_after"] as? Int,
      screenTimeOff: dusk?["screen_time_off"] as? Bool ?? false, late: late)
  }
}
