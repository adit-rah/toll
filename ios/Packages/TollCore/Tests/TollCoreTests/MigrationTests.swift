import Foundation
import Testing

@testable import TollCore

/// Step 2's state file becomes a Sleep block at Home (docs/architecture.md, Migration).
struct MigrationTests {
  let v1 = """
    {"settings":{"window":{"start":"22:30","end":"07:00"},
      "home":{"latitude":51.5,"longitude":-0.12,"radiusMeters":150},"blocked":"AQ=="},
     "presence":{"isHome":true,"at":"2026-11-17T20:00:00Z"},"homeCheck":"location",
     "entitled":true,"purchased":false,"trialStart":"2026-11-17T15:00:00Z",
     "blockOn":true,"blockEndsAt":"2026-11-18T07:00:00Z","lastNightEnd":"2026-11-17T07:00:00Z",
     "setupFinishedAt":"2026-11-17T15:00:00Z","scheduledWindow":{"start":"22:30","end":"07:00"},
     "unlocks":{"spent":1,"cleanNights":2,"used":1},
     "door":{"app":"CQ==","waitEndsAt":"2026-11-17T23:01:30Z","usedUp":false}}
    """

  @Test func readsSchemaOneAsASleepBlockAtHome() {
    let state = DuskStore.decode(Data(v1.utf8))
    #expect(state.schema == DuskState.schema)
    #expect(state.blocks.count == 1)
    let sleep = state.sleepBlock
    #expect(sleep?.schedule == .everyDay(usual))
    #expect(sleep?.apps == Data([1]))
    #expect(sleep?.place == PlaceID("home"))
    #expect(state.places.first?.radiusMeters == 150)
    #expect(state.presence[PlaceID("home")]?.isInside == true)
    #expect(state.runtime.active[BlockID("sleep")] != nil)
    #expect(state.runtime.scheduledWindows == nil)
    #expect(state.trial.start != nil)
    #expect(state.unlocks.spent == 1)
    // A door from before D67 still names an app; it reads as a pause.
    #expect(state.door?.phase == .waiting)
    #expect(state.setupFinishedAt != nil)
  }

  @Test func windowOnlyBecomesScheduleOnly() {
    let state = DuskStore.decode(
      Data(v1.replacingOccurrences(of: "\"location\"", with: "\"windowOnly\"").utf8))
    #expect(state.location == .scheduleOnly)
  }

  @Test func schemaTwoRoundTripsAndToleratesMissingKeys() throws {
    var state = setUp()
    state.places.append(libraryPlace)
    state.blocks.append(studyBlock())
    run(&state, date(2026, 11, 17, 23))
    let data = try DuskStore.encoder.encode(state)
    #expect(DuskStore.decode(data) == state)
    let sparse = DuskStore.decode(Data(#"{"schema":2,"blocks":[]}"#.utf8))
    #expect(sparse.blocks.isEmpty)
    #expect(sparse.location == .places)
  }

  @Test func idsKeyJSONObjects() throws {
    var state = setUp()
    run(&state, date(2026, 11, 17, 23))
    let text = String(decoding: try DuskStore.encoder.encode(state), as: UTF8.self)
    #expect(text.contains(#""presence":{"home":"#))
  }

  @Test func garbageStartsOver() {
    #expect(DuskStore.decode(Data("nope".utf8)) == DuskState())
  }
}
