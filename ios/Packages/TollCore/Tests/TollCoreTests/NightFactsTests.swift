import Foundation
import SleepModel
import Testing

@testable import TollCore

/// One record per Sleep night, from the log (#51).
struct NightFactsTests {
  let sleep = BlockID("sleep")

  func line(
    _ at: Date, _ cause: ReconcileCause, active: [BlockID], home: Bool? = true,
    door: Door.Phase? = nil, entitled: Bool = true, screenTime: Bool? = true
  ) -> Transition {
    Transition(
      at: at, cause: cause, blockOn: !active.isEmpty, changed: false, home: home,
      inWindow: true, entitled: entitled, door: door, active: active, screenTime: screenTime)
  }

  var log: [Transition] {
    [
      line(date(2026, 11, 16, 21), .arrived, active: []),
      line(date(2026, 11, 16, 22, 30), .windowStart, active: [sleep]),
      line(date(2026, 11, 16, 23), .blockScreen, active: [sleep]),
      line(date(2026, 11, 16, 23, 10), .doorAsked, active: [sleep]),
      line(date(2026, 11, 16, 23, 12), .doorStart, active: [sleep], door: .open),
      line(date(2026, 11, 16, 23, 17), .doorEnd, active: [sleep]),
      line(date(2026, 11, 17, 0, 40), .blockScreen, active: [sleep]),
      line(date(2026, 11, 17, 7), .windowEnd, active: []),
      // The next night, away.
      line(date(2026, 11, 17, 22, 30), .windowStart, active: [], home: false),
    ]
  }

  func nights(now: Date) -> [NightFacts] {
    NightFacts.ended(
      log: log, sleep: sleepBlock(), since: date(2026, 11, 16, 12), now: now, calendar: london)
  }

  @Test func aBlockedNight() throws {
    let night = try #require(nights(now: date(2026, 11, 17, 9)).first)
    #expect(night.blockStart == date(2026, 11, 16, 22, 30))
    #expect(night.blockEnd == date(2026, 11, 17, 7))
    #expect(night.homeArrival == date(2026, 11, 16, 21))
    #expect(night.stops == 2 && night.doorAsks == 1)
    #expect(night.lastReach == date(2026, 11, 17, 0, 40))
    #expect(night.unlocksUsed == 1 && night.unlocksReturned == 0)
    #expect(!night.away && !night.paused && !night.screenTimeOff)
  }

  @Test func onlyEndedNightsAndAwayNamed() {
    #expect(nights(now: date(2026, 11, 17, 9)).count == 1)
    let both = nights(now: date(2026, 11, 18, 9))
    #expect(both.count == 2)
    #expect(both[1].away && !both[1].ran)
  }

  @Test func theLineIsTheSleepModelsRecord() throws {
    let night = try #require(nights(now: date(2026, 11, 17, 9)).first)
    let data = try #require(NightRecordLine.encode(night, calendar: london, model: stamp))
    let record = try JSONDecoder().decode(NightRecord.self, from: data)
    #expect(record.night == "2026-11-16")
    #expect(record.plannedBedtime.hasPrefix("2026-11-16T22:30:00"))
    #expect(record.blockScreens == 3)
    #expect(record.policy == "fixed")
    #expect(record.sleepOnset == nil)
    let extras = try #require(
      (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["dusk"] as? [String: Any])
    #expect(extras["stops"] as? Int == 2)
  }

  @Test func theLogKeepsEachNightOnce() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "nights-\(UUID().uuidString).jsonl")
    let file = NightLog(url: url)
    #expect(file.record(nights(now: date(2026, 11, 18, 9)), calendar: london, model: stamp) == 2)
    #expect(file.record(nights(now: date(2026, 11, 18, 9)), calendar: london, model: stamp) == 0)
    #expect(file.lines().count == 2)
  }
}
