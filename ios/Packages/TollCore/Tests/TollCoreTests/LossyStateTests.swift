import Foundation
import Testing

@testable import TollCore

/// #140 risk 1, each trigger: one value this build can't read loses that value, never the person.
/// On main every one of these read as an empty state, which the next wake wrote over the file.
struct LossyStateTests {
  typealias JSON = [String: Any]

  /// The newest past format with one change made to it.
  func read(_ change: (inout JSON) throws -> Void) throws -> DuskState {
    let data = try StateFixtureTests.fixture("v2-09-helpers")
    var json = try #require(try JSONSerialization.jsonObject(with: data) as? JSON)
    try change(&json)
    let state = DuskStore.decode(try JSONSerialization.data(withJSONObject: json))
    #expect(state.sleepBlock?.schedule == .everyDay(usual), "the night survives")
    #expect(state.setupFinishedAt != nil, "no setup again")
    #expect(state.trial.start == date(2026, 11, 17, 15))
    return state
  }

  func block(_ json: inout JSON, _ index: Int, _ change: (inout JSON) -> Void) throws {
    var blocks = try #require(json["blocks"] as? [JSON])
    change(&blocks[index])
    json["blocks"] = blocks
  }

  func rule(_ block: inout JSON, _ change: (inout JSON) -> Void) {
    var schedule = block["schedule"] as? JSON ?? [:]
    var rules = schedule["rules"] as? [JSON] ?? []
    change(&rules[0])
    schedule["rules"] = rules
    block["schedule"] = schedule
  }

  func nested(_ json: inout JSON, _ key: String, _ change: (inout JSON) -> Void) {
    var inner = json[key] as? JSON ?? [:]
    change(&inner)
    json[key] = inner
  }

  // MARK: Unknown enum values

  @Test func anUnknownBlockKindIsAPlainBlock() throws {
    let state = try read { try block(&$0, 1) { $0["kind"] = "nap" } }
    #expect(state.blocks.map(\.kind) == [.sleep, .other])
    #expect(state.blocks.last?.apps == Data([2]))
  }

  @Test func anUnknownLocationModeRunsOnHoursAlone() throws {
    let state = try read { $0["location"] = "wifi" }
    #expect(state.location == .scheduleOnly)
  }

  @Test func anUnknownGapModeHoldsTheGap() throws {
    let state = try read { nested(&$0, "gap") { $0["mode"] = "adaptive" } }
    #expect(state.gap.mode == .fixed)
    #expect(state.gap.minutes == 15)
  }

  @Test func anUnknownWeekdayIsDropped() throws {
    let state = try read {
      try block(&$0, 1) { rule(&$0) { $0["days"] = [1, 2, 3, 4, 5, 8] } }
    }
    #expect(state.blocks.last?.schedule.rules.first?.days == Weekday.weekdays)
  }

  @Test func anUnknownHeldEditIsDropped() throws {
    let state = try read { nested(&$0, "pending") { $0["study"] = ["archive": [String: Any]()] } }
    #expect(state.pending.keys.map(\.raw) == ["sleep"])
  }

  // MARK: Missing keys in types that had synthesized decoding

  @Test func aPlaceWithoutANameKeepsItsCentre() throws {
    let state = try read { json in
      var places = json["places"] as? [JSON] ?? []
      places[1]["name"] = nil
      places[1]["radiusMeters"] = nil
      json["places"] = places
    }
    #expect(state.places.last?.latitude == 51.52)
    #expect(state.places.last?.radiusMeters == 150)
  }

  @Test func aPlaceWithoutACentreIsDroppedAlone() throws {
    let state = try read { json in
      var places = json["places"] as? [JSON] ?? []
      places[1]["latitude"] = nil
      json["places"] = places
    }
    #expect(state.places.map(\.id) == [PlaceID("home")])
  }

  @Test func presenceWithoutATimeIsDropped() throws {
    let state = try read { nested(&$0, "presence") { $0["home"] = ["isInside": true] } }
    #expect(state.presence.isEmpty)
  }

  @Test func aPauseWithoutItsWaitIsNoPause() throws {
    let state = try read { nested(&$0, "door") { $0["waitEndsAt"] = nil } }
    #expect(state.door == nil)
  }

  @Test func aRuleWithoutHoursDropsOnlyThatBlock() throws {
    let state = try read { try block(&$0, 1) { rule(&$0) { $0["window"] = nil } } }
    #expect(state.blocks.map(\.kind) == [.sleep])
  }

  @Test func hoursThatArentATimeDropOnlyThatBlock() throws {
    let state = try read {
      try block(&$0, 1) { rule(&$0) { $0["window"] = ["start": "9 am", "end": "17:00"] } }
    }
    #expect(state.blocks.map(\.kind) == [.sleep])
  }

  @Test func aClockAnchorWithoutItsOffsetIsForgotten() throws {
    let state = try read { nested(&$0, "runtime") { $0["clockAnchor"] = ["bootID": "boot"] } }
    #expect(state.runtime.clockAnchor == nil)
    #expect(state.runtime.active[BlockID("sleep")] != nil)
  }

  @Test func helpersKeepTheBreathWhenTheSwitchIsMissing() throws {
    let state = try read { nested(&$0, "helpers") { $0["on"] = nil } }
    #expect(state.helpers == Helpers(on: true, breathMinutes: 5))
  }

  @Test func noSchemaReadsAsTheBlocksFile() throws {
    let state = try read { $0["schema"] = nil }
    #expect(state.blocks.count == 2)
  }

  @Test func whatWasGivenUpIsCounted() throws {
    var json = try #require(
      try JSONSerialization.jsonObject(with: try StateFixtureTests.fixture("v2-09-helpers"))
        as? JSON)
    json["location"] = "wifi"
    nested(&json, "presence") { $0["home"] = ["isInside": true] }
    let reading = DuskStore.reading(try JSONSerialization.data(withJSONObject: json))
    #expect(reading.lost == 2)
  }
}
