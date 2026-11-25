import Foundation

/// A person whose state file lost their night is brought back from what survives (#140): the
/// latest night record holds the night's hours and its gap, and the app puts the free nights'
/// start back from the Keychain at its next launch (`TrialClock.settle`). The night's apps can't
/// come back from a record, so the block shows "No apps" until they're chosen again. Setup shows
/// again only when there's no record to start from.
enum Recovery {
  static func restoreNight(_ state: inout DuskState, from record: [String: Any]?, now: Date) {
    guard state.sleepBlock == nil else { return }
    guard let record, let window = window(record) else {
      state.setupFinishedAt = nil
      return
    }
    let gap = (record["gap_min"] as? Int).map { min(max($0, 0), TollConfig.defaults.gap.manualMax) }
    state.blocks.insert(
      Block(
        name: Copy.Setup.nightName, kind: .sleep, place: nil, schedule: .everyDay(window),
        apps: nil),
      at: 0)
    if state.setupFinishedAt == nil {
      state.gap = Gap()
      state.gap.minutes = gap ?? 0
      state.setupFinishedAt = now
    }
  }

  /// Bed to wake, as the clock read them that night: the record's times are written in the phone's
  /// own zone, so the hours and minutes in the text are the night's.
  static func window(_ record: [String: Any]) -> TimeWindow? {
    func clock(_ key: String) -> ClockTime? {
      guard let text = record[key] as? String, let t = text.firstIndex(of: "T") else { return nil }
      let parts = text[text.index(after: t)...].prefix(5).split(separator: ":").compactMap {
        Int($0)
      }
      guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else {
        return nil
      }
      return ClockTime(hour: parts[0], minute: parts[1])
    }
    guard let bed = clock("bed") ?? clock("planned_bedtime"), let wake = clock("planned_wake")
    else { return nil }
    let window = TimeWindow(start: bed, end: wake)
    return window.isValid ? window : nil
  }
}
