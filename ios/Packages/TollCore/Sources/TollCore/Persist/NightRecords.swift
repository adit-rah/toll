import Foundation

/// The night record as a line of the night log (#51): the sleep model's contract 1 fields, with the
/// names and formats `datascience/` and `SleepModel.NightRecord` read, plus Dusk's own signals under
/// `dusk`, which both ignore. Health's fields stay empty until the app reads sleep (#86).
public enum NightRecordLine {
  /// No model chooses the start yet: the block runs on its plan.
  static let policy = "fixed"
  static let modelVersion = "sleep-model.v0"

  public static func encode(_ facts: NightFacts, calendar: Calendar) -> Data? {
    let iso = ISO8601DateFormatter()
    iso.timeZone = calendar.timeZone
    iso.formatOptions = [.withInternetDateTime]
    func time(_ date: Date?) -> Any { date.map(iso.string(from:)) ?? NSNull() }
    let day = DateFormatter()
    day.calendar = calendar
    day.timeZone = calendar.timeZone
    day.locale = Locale(identifier: "en_US_POSIX")
    day.dateFormat = "yyyy-MM-dd"
    let record: [String: Any] = [
      "night": day.string(from: facts.night),
      "planned_bedtime": time(facts.plannedStart),
      "planned_wake": time(facts.plannedEnd),
      "block_start": time(facts.blockStart),
      "block_end": time(facts.blockStart == nil ? nil : facts.blockEnd ?? facts.plannedEnd),
      "action_offset_min": 0,
      "action_prob": 1.0,
      "model_version": modelVersion,
      "policy": policy,
      "home_arrival": time(facts.homeArrival),
      "away_all_night": facts.away,
      "weekend": facts.weekend,
      "tz_changed": false,
      "block_screens": facts.stops + facts.doorAsks,
      "unlocks_used": facts.unlocksUsed,
      "unlocks_returned": facts.unlocksReturned,
      "sleep_onset": NSNull(),
      "wake": NSNull(),
      "asleep_min": NSNull(),
      "awake_min": NSNull(),
      "sleep_source": NSNull(),
      "dusk": [
        "ran": facts.ran,
        "stops": facts.stops,
        "door_asks": facts.doorAsks,
        "last_reach": time(facts.lastReach),
        "paused": facts.paused,
        "screen_time_off": facts.screenTimeOff,
      ] as [String: Any],
    ]
    return try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
  }
}

/// The night log in the App Group: one record per ended Sleep night, appended once and kept, so the
/// nights outlive the transition log's 2000 lines. Written by the app only.
public struct NightLog: Sendable {
  public let url: URL

  public init(url: URL = AppGroup.file("nights.jsonl")) {
    self.url = url
  }

  /// Appends the nights not yet in the file; returns how many.
  @discardableResult
  public func record(_ nights: [NightFacts], calendar: Calendar) -> Int {
    let known = Set(
      lines().compactMap { line -> String? in
        (try? JSONSerialization.jsonObject(with: line) as? [String: Any])?["night"] as? String
      })
    var added = 0
    for facts in nights {
      guard let line = NightRecordLine.encode(facts, calendar: calendar),
        let night = (try? JSONSerialization.jsonObject(with: line) as? [String: Any])?["night"]
          as? String,
        !known.contains(night)
      else { continue }
      CoordinatedFile.append(line + Data([0x0A]), to: url)
      added += 1
    }
    return added
  }

  /// The raw lines, oldest first, for export and for the measures (#87).
  public func lines() -> [Data] {
    (CoordinatedFile.read(url) ?? Data()).split(separator: 0x0A).map { Data($0) }
  }
}
