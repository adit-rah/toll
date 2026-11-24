import Foundation
import Testing

@testable import SleepModel

/// Decisions D76: records gain the gap and bed; `planned_bedtime` is bed. Older records still read.
struct NightRecordTests {
  func record(_ extra: String = "") throws -> NightRecord {
    let json = """
      {"night":"2026-11-20","planned_bedtime":"2026-11-20T23:00:00-05:00",
       "planned_wake":"2026-11-21T07:00:00-05:00","block_start":"2026-11-20T22:30:00-05:00",
       "block_end":"2026-11-21T07:00:00-05:00","action_offset_min":0,"action_prob":1.0,
       "model_version":"sleep-model.v0","policy":"fixed","home_arrival":null,
       "away_all_night":false,"weekend":false,"tz_changed":false,
       "sleep_onset":"2026-11-20T23:20:00-05:00"\(extra)}
      """
    return try JSONDecoder().decode(NightRecord.self, from: Data(json.utf8))
  }

  @Test func anOlderRecordHasNoGap() throws {
    let night = try record()
    #expect(night.bed == nil && night.gap == 0)
    #expect(night.bedtime == night.plannedBedtime)
    #expect(night.features(.builtIn).onset == 20)
  }

  @Test func sleepIsMeasuredFromBedNotTheLock() throws {
    let night = try record(#","bed":"2026-11-20T23:00:00-05:00","gap_min":30"#)
    #expect(night.gap == 30)
    #expect(night.features(.builtIn).skip == nil)
    #expect(night.features(.builtIn).onset == 20)
  }
}
