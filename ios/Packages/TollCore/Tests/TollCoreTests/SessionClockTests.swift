import Foundation
import Testing

@testable import TollCore

struct SessionClockTests {
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)
  let boot = MonotonicInstant(bootID: "boot-1", seconds: 1_000)

  func session() -> ActiveSession {
    ActiveSession(appRefs: ["ig"], minutes: 5, startedAt: t0, startedMonotonic: boot)
  }

  func mono(_ elapsed: Double, boot id: String = "boot-1") -> MonotonicInstant {
    MonotonicInstant(bootID: id, seconds: 1_000 + elapsed)
  }

  @Test func startingASessionKeepsTheMonotonicStart() throws {
    let machine = GateMachine(config: TollConfig.Gate(), timeZone: .gmt)
    var state = SharedGateState()
    _ = machine.enter(appRef: "ig", ledger: GateLedger(), state: &state, now: t0, monotonic: boot)
    let start = try #require(
      machine.startSession(minutes: 5, state: &state, now: t0, monotonic: boot))
    #expect(start.session.startedMonotonic == boot)
    #expect(state.sessions.first?.startedMonotonic == boot)
  }

  @Test func clocksThatAgreeFollowTheWallClock() {
    let s = session()
    #expect(!s.isExpired(at: t0.addingTimeInterval(299), monotonic: mono(330), tolerance: 60))
    #expect(s.isExpired(at: t0.addingTimeInterval(300), monotonic: mono(270), tolerance: 60))
    #expect(s.minutesLeft(at: t0.addingTimeInterval(181), monotonic: mono(181), tolerance: 60) == 2)
  }

  @Test func aClockSetBackMidSessionStillExpiresOnTime() {
    let s = session()
    let setBack = t0.addingTimeInterval(300 - 3600)
    #expect(!s.isExpired(at: setBack))
    #expect(
      !s.isExpired(at: setBack.addingTimeInterval(-1), monotonic: mono(299), tolerance: 60))
    #expect(s.isExpired(at: setBack, monotonic: mono(300), tolerance: 60))
    #expect(
      s.minutesLeft(at: t0.addingTimeInterval(-3600), monotonic: mono(120), tolerance: 60) == 3)

    let math = DayMath(timeZone: .gmt, resetHour: 4)
    let blocks = [BlockDefinition(id: "b1", appRefs: ["ig"], schedule: .always)]
    let byWallClock = ShieldPlan.make(blocks: blocks, sessions: [s], at: setBack, math: math)
    #expect(byWallClock.unlocked == ["ig"] && byWallClock.shielded.isEmpty)
    let guarded = ShieldPlan.make(
      blocks: blocks, sessions: [s], at: setBack, math: math, monotonic: mono(300), tolerance: 60)
    #expect(guarded.shielded == ["ig"] && guarded.unlocked.isEmpty)
  }

  @Test func aClockSetForwardStillEndsTheSessionSoItIsNeverLeftWithoutAWake() {
    let s = session()
    let forward = t0.addingTimeInterval(3600)
    #expect(s.isExpired(at: forward))
    #expect(s.isExpired(at: forward, monotonic: mono(30), tolerance: 60))
    #expect(s.minutesLeft(at: forward, monotonic: mono(30), tolerance: 60) == 0)
  }

  @Test func acrossARebootOnlyTheWallClockIsLeft() {
    let s = session()
    let rebooted = mono(-990, boot: "boot-2")
    #expect(!s.isExpired(at: t0.addingTimeInterval(299), monotonic: rebooted, tolerance: 60))
    #expect(s.isExpired(at: t0.addingTimeInterval(300), monotonic: rebooted, tolerance: 60))
    #expect(!s.isExpired(at: t0.addingTimeInterval(300 - 3600), monotonic: rebooted, tolerance: 60))
  }

  @Test func aSessionWrittenBeforeTheGuardDecodesAndRunsOnTheWallClock() throws {
    let json = """
      {"blocks":[],"resetHour":4,"notificationsAllowed":false,"unblocks":{},
       "sessions":[{"id":"7B0E5C1C-3A5E-4E0B-9A3B-0C7B8E4D2F10","appRefs":["ig"],"minutes":5,
                    "startedAt":1800000000000,"expiresAt":1800000300000,"blockRef":"b1"}]}
      """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    let state = try decoder.decode(SharedGateState.self, from: Data(json.utf8))
    let old = try #require(state.sessions.first)
    #expect(old.startedMonotonic == nil && old.blockRef == "b1")
    #expect(!old.isExpired(at: t0.addingTimeInterval(299), monotonic: mono(900), tolerance: 60))
    #expect(old.isExpired(at: t0.addingTimeInterval(300), monotonic: mono(0), tolerance: 60))

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    let guarded = session()
    let again = try decoder.decode(ActiveSession.self, from: try encoder.encode(guarded))
    #expect(again == guarded && again.startedMonotonic == boot)
  }
}
