import Foundation

/// Health's sleep reaches a night record as a correction (D92, #144): the night is recorded at its
/// end, before a watch has synced, so the next day the app appends the same night again with a
/// higher `rev` and the contract's sleep fields filled. A line is never rewritten.
extension NightRecordLine {
  /// The record with Health's sleep, one revision up; nil when it already has sleep or doesn't
  /// parse.
  public static func corrected(_ line: Data, with sleep: SleepNight, calendar: Calendar) -> Data? {
    guard var record = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
      record["sleep_onset"] == nil || record["sleep_onset"] is NSNull
    else { return nil }
    let iso = ISO8601DateFormatter()
    iso.timeZone = calendar.timeZone
    iso.formatOptions = [.withInternetDateTime]
    record["record"] = format
    record["rev"] = (record["rev"] as? Int ?? 1) + 1
    record["sleep_onset"] = iso.string(from: sleep.onset)
    record["wake"] = iso.string(from: sleep.wake)
    record["asleep_min"] = sleep.asleepMinutes
    record["awake_min"] = sleep.awakeMinutes
    record["sleep_source"] = sleep.source.rawValue
    if var dusk = record["dusk"] as? [String: Any] {
      dusk["by"] = Writer.app.rawValue
      record["dusk"] = dusk
    }
    return try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
  }
}

extension NightLog {
  /// Appends a correction for each recent night that has no sleep yet and that Health has.
  /// Returns how many, or nil if one couldn't be written.
  @discardableResult
  public func correct(with sleep: [SleepNight], calendar: Calendar) -> Int? {
    let byKey = Dictionary(
      sleep.map { (NightRecordLine.key($0.night, calendar: calendar), $0) },
      uniquingKeysWith: { first, _ in first })
    var added = 0
    for line in current() {
      guard let key = Self.fields(line)?.night, let night = byKey[key],
        let corrected = NightRecordLine.corrected(line, with: night, calendar: calendar)
      else { continue }
      guard CoordinatedFile.append(corrected + Data([0x0A]), to: url) else { return nil }
      added += 1
    }
    return added
  }

  /// The nights that still lack Health's sleep, oldest first, for the adapter to ask about.
  public func missingSleep(since: Date, calendar: Calendar) -> [String] {
    let from = NightRecordLine.key(since, calendar: calendar)
    return current().compactMap { line in
      guard let record = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
        let night = record["night"] as? String, night >= from,
        record["sleep_onset"] == nil || record["sleep_onset"] is NSNull
      else { return nil }
      return night
    }
  }
}
