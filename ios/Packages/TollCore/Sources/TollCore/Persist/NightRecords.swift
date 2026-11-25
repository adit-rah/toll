import Foundation

/// The model and policy that chose a night's start, as the record says: from the artifact the app
/// runs, never a constant beside it (#140).
public struct ModelStamp: Sendable, Equatable {
  public var version: String
  public var policy: String

  public init(version: String, policy: String) {
    self.version = version
    self.policy = policy
  }

  /// No model chooses the start yet: the block runs on its plan (D62).
  public static func fixed(_ version: String) -> ModelStamp {
    ModelStamp(version: version, policy: "fixed")
  }
}

/// The night record as a line of the night log (#51): the sleep model's contract 1 fields, with the
/// names and formats `datascience/` and `SleepModel.NightRecord` read, plus Dusk's own signals under
/// `dusk`, which both ignore. Health's fields stay empty until the app reads sleep (#86).
public enum NightRecordLine {
  /// The line's own format. 1 had no `record` or `rev`; 2 added both (#140). A line without them is
  /// format 1, revision 1.
  public static let format = 2

  /// Who wrote a line, under `dusk.by`: the monitor at the night's sweep, or the app on opening.
  public enum Writer: String, Sendable {
    case app, monitor
  }

  public static func encode(
    _ facts: NightFacts, calendar: Calendar, model: ModelStamp, rev: Int = 1, by: Writer = .app
  ) -> Data? {
    let iso = ISO8601DateFormatter()
    iso.timeZone = calendar.timeZone
    iso.formatOptions = [.withInternetDateTime]
    func time(_ date: Date?) -> Any { date.map(iso.string(from:)) ?? NSNull() }
    let record: [String: Any] = [
      "record": format,
      "rev": rev,
      "night": key(facts.night, calendar: calendar),
      // Bed, not the lock: sleep is measured from bed (D76). The lock is bed minus `gap_min`.
      "planned_bedtime": time(facts.bed),
      "bed": time(facts.bed),
      "gap_min": facts.gap,
      "planned_wake": time(facts.plannedEnd),
      "block_start": time(facts.blockStart),
      "block_end": time(facts.blockStart == nil ? nil : facts.blockEnd ?? facts.plannedEnd),
      "action_offset_min": 0,
      "action_prob": 1.0,
      "model_version": model.version,
      "policy": model.policy,
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
      // Private (D80): which helper before bed was last opened, or null. Never shown, never counted.
      "helper": facts.helper.map { $0.rawValue as Any } ?? NSNull(),
      "dusk": [
        "by": by.rawValue,
        "ran": facts.ran,
        "stops": facts.stops,
        "door_asks": facts.doorAsks,
        "last_reach": time(facts.lastReach),
        "paused": facts.paused,
        "screen_time_off": facts.screenTimeOff,
        "locked_min": Int((facts.locked / 60).rounded()),
        "taps": facts.taps.map(iso.string(from:)),
      ] as [String: Any],
    ]
    return try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
  }

  /// The night's key as the line writes it: the day it starts, noon to noon.
  static func key(_ night: Date, calendar: Calendar) -> String {
    let day = DateFormatter()
    day.calendar = calendar
    day.timeZone = calendar.timeZone
    day.locale = Locale(identifier: "en_US_POSIX")
    day.dateFormat = "yyyy-MM-dd"
    return day.string(from: night)
  }
}

/// The night log in the App Group: one record per ended Sleep night, appended and never rewritten,
/// so the nights outlive the transition log's 2000 lines. A correction is a new line for the same
/// night with a higher `rev`; every reader takes the highest (#140).
public struct NightLog: Sendable {
  public let url: URL

  public init(url: URL = AppGroup.file("nights.jsonl")) {
    self.url = url
  }

  /// Appends the nights not yet in the file; returns how many, or nil if any couldn't be written.
  /// `known` limits the check to the lines already read, for the monitor, which reads only the
  /// file's end.
  @discardableResult
  public func record(
    _ nights: [NightFacts], calendar: Calendar, model: ModelStamp,
    by writer: NightRecordLine.Writer = .app, known lines: [Data]? = nil
  ) -> Int? {
    let known = Set((lines ?? self.lines()).compactMap { Self.fields($0)?.night })
    var added = 0
    for facts in nights where !known.contains(NightRecordLine.key(facts.night, calendar: calendar))
    {
      guard let line = NightRecordLine.encode(facts, calendar: calendar, model: model, by: writer)
      else { return nil }
      guard CoordinatedFile.append(line + Data([0x0A]), to: url) else { return nil }
      added += 1
    }
    return added
  }

  /// The raw lines, oldest first, for export and for the measures (#87).
  public func lines() -> [Data] {
    (CoordinatedFile.read(url) ?? Data()).split(separator: 0x0A).map { Data($0) }
  }

  /// One line per night, its highest revision (the first written of equals), in night order.
  public func current() -> [Data] {
    Self.current(lines())
  }

  static func current(_ lines: [Data]) -> [Data] {
    var best: [String: (rev: Int, line: Data)] = [:]
    for line in lines {
      guard let fields = fields(line) else { continue }
      if let held = best[fields.night], held.rev >= fields.rev { continue }
      best[fields.night] = (fields.rev, line)
    }
    return best.sorted { $0.key < $1.key }.map(\.value.line)
  }

  /// The newest night's record, for bringing a lost night back (`Recovery`).
  func latestRecord() -> [String: Any]? {
    current().last.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
  }

  static func fields(_ line: Data) -> (night: String, rev: Int)? {
    guard let record = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
      let night = record["night"] as? String
    else { return nil }
    return (night, record["rev"] as? Int ?? 1)
  }
}
