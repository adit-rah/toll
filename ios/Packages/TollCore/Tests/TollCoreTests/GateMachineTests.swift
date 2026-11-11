import Foundation
import Testing

@testable import TollCore

struct GateMachineTests {
  let machine = GateMachine(
    config: TollConfig.Gate(), timeZone: TimeZone(identifier: "UTC") ?? .gmt)
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)
  let boot = MonotonicInstant(bootID: "b", seconds: 0)

  func ledger(free: Int, waited: Int) -> GateLedger {
    var l = GateLedger()
    l.freePasses = free
    l.waitedPasses = waited
    return l
  }

  @Test func freePassOpensThePickerAndRecordsNothingUntilUsed() {
    var state = SharedGateState()
    state.blocks = [BlockDefinition(id: "b1", appRefs: ["ig", "tt"], schedule: .always)]
    let events = machine.enter(
      appRef: "ig", ledger: GateLedger(), state: &state, now: t0, monotonic: boot)
    #expect(events.isEmpty)
    #expect(state.pendingPass?.appRefs == ["ig"] && state.pendingPass?.free == true)
    #expect(state.pendingPass?.origin == .shield && state.pendingPass?.blockRef == "b1")
    #expect(state.pendingPass?.deferred == false)
    #expect(state.wait == nil)
  }

  @Test func noFreePassStartsTheLadderedWait() {
    var state = SharedGateState()
    let events = machine.enter(
      appRef: "ig", ledger: ledger(free: 2, waited: 1), state: &state, now: t0, monotonic: boot)
    #expect(events.map(\.kind) == [.waitStarted])
    #expect(state.wait?.minutes == 5 && state.wait?.number == 2)
  }

  @Test func aSecondHitJoinsWithoutResettingOrExtending() {
    var state = SharedGateState()
    _ = machine.enter(
      appRef: "ig", ledger: ledger(free: 2, waited: 0), state: &state, now: t0, monotonic: boot)
    let later = t0.addingTimeInterval(60)
    let events = machine.enter(
      appRef: "tt", ledger: ledger(free: 2, waited: 0), state: &state, now: later,
      monotonic: MonotonicInstant(bootID: "b", seconds: 60))
    #expect(events.isEmpty)
    #expect(state.wait?.appRefs == ["ig", "tt"])
    #expect(state.wait?.startedAt == t0 && state.wait?.minutes == 3)
  }

  @Test func theWaitCompletesIntoAWaitedPassRecordedWhenUsed() throws {
    var state = SharedGateState()
    _ = machine.enter(
      appRef: "ig", ledger: ledger(free: 2, waited: 0), state: &state, now: t0, monotonic: boot)
    state.wait?.join("tt")
    #expect(
      machine.tick(
        state: &state, now: t0.addingTimeInterval(179),
        monotonic: MonotonicInstant(bootID: "b", seconds: 179)
      ).isEmpty)
    let events = machine.tick(
      state: &state, now: t0.addingTimeInterval(400),
      monotonic: MonotonicInstant(bootID: "b", seconds: 400))
    #expect(events.map(\.kind) == [.waitCompleted])
    #expect(state.wait == nil && state.pendingPass?.appRefs == ["ig", "tt"])
    #expect(state.pendingPass?.free == false && state.pendingPass?.waitMinutes == 3)
    let later = t0.addingTimeInterval(460)
    let start = try #require(machine.startSession(minutes: 5, state: &state, now: later))
    #expect(start.pass.kind == .pass && start.pass.occurredAt == later)
    #expect(start.pass.free == false && start.pass.waitMinutes == 3)
    #expect(start.pass.appRef == "ig" && start.pass.appRefs == ["ig", "tt"])
  }

  @Test func cancelAbandonsAndLeavingDoesNot() {
    var state = SharedGateState()
    _ = machine.enter(
      appRef: "ig", ledger: ledger(free: 2, waited: 0), state: &state, now: t0, monotonic: boot)
    #expect(machine.tick(state: &state, now: t0.addingTimeInterval(10), monotonic: nil).isEmpty)
    #expect(state.wait != nil)
    #expect(machine.cancelWait(state: &state, now: t0).map(\.kind) == [.waitAbandoned])
    #expect(state.wait == nil)
  }

  @Test func sessionRunsForTheChosenMinutesOfWallClockTime() throws {
    var state = SharedGateState()
    _ = machine.enter(appRef: "ig", ledger: GateLedger(), state: &state, now: t0, monotonic: boot)
    let start = try #require(machine.startSession(minutes: 10, state: &state, now: t0))
    #expect(start.session.appRefs == ["ig"] && start.session.minutes == 10)
    #expect(start.session.expiresAt == t0.addingTimeInterval(600))
    #expect(!start.session.isExpired(at: t0.addingTimeInterval(599)))
    #expect(start.session.isExpired(at: t0.addingTimeInterval(600)))
    #expect(start.session.minutesLeft(at: t0.addingTimeInterval(181)) == 7)
    #expect(start.pass.free == true && start.pass.waitMinutes == 0 && start.pass.appRefs == ["ig"])
    #expect(state.pendingPass == nil && state.sessions.count == 1 && state.lastSessionMinutes == 10)
    #expect(machine.startSession(minutes: 5, state: &state, now: t0) == nil)
    #expect(machine.sessionEnded(start.session, at: t0).sessionMinutes == 10)
  }

  @Test func aPendingPassAbsorbsAnotherHitAndLapsesAtDayEnd() {
    var state = SharedGateState()
    _ = machine.enter(appRef: "ig", ledger: GateLedger(), state: &state, now: t0, monotonic: boot)
    #expect(
      machine.enter(appRef: "tt", ledger: GateLedger(), state: &state, now: t0, monotonic: boot)
        .isEmpty)
    #expect(state.pendingPass?.appRefs == ["ig", "tt"])
    machine.expireStalePass(state: &state, now: t0.addingTimeInterval(60))
    #expect(state.pendingPass != nil)
    machine.expireStalePass(state: &state, now: t0.addingTimeInterval(86_400))
    #expect(state.pendingPass == nil)
  }

  @Test func aPassThatIsNeverUsedCostsNothing() throws {
    var state = SharedGateState()
    var recorded: [GateEvent] = []
    recorded += machine.enter(
      appRef: "ig", ledger: GateLedger(), state: &state, now: t0, monotonic: boot)
    machine.discardPass(state: &state)
    #expect(state.pendingPass == nil)
    #expect(GateLedger(eventsOfToday: recorded).passes == 0)
    recorded += machine.enter(
      appRef: "ig", ledger: GateLedger(eventsOfToday: recorded), state: &state, now: t0,
      monotonic: boot)
    recorded.append(try #require(machine.startSession(minutes: 5, state: &state, now: t0)).pass)
    #expect(GateLedger(eventsOfToday: recorded).freePasses == 1)
  }

  @Test func aDeferredPassIsKeptAndTheNextHitBringsItBack() {
    var state = SharedGateState()
    _ = machine.enter(appRef: "ig", ledger: GateLedger(), state: &state, now: t0, monotonic: boot)
    machine.deferPass(state: &state)
    #expect(state.pendingPass?.deferred == true)
    machine.resumePass(state: &state)
    #expect(state.pendingPass?.deferred == false)
    machine.deferPass(state: &state)
    _ = machine.enter(appRef: "tt", ledger: GateLedger(), state: &state, now: t0, monotonic: boot)
    #expect(state.pendingPass?.deferred == false && state.pendingPass?.appRefs == ["ig", "tt"])
  }

  @Test func unblockingABlockWithAFreePassCoversEveryApp() throws {
    let block = BlockDefinition(id: "b1", appRefs: ["ig", "tt"], schedule: .always)
    var state = SharedGateState()
    let events = machine.enter(
      block: block, ledger: GateLedger(), state: &state, now: t0, monotonic: boot)
    #expect(events.isEmpty)
    #expect(state.pendingPass?.origin == .app && state.pendingPass?.blockRef == "b1")
    let start = try #require(machine.startSession(minutes: 5, state: &state, now: t0))
    #expect(start.session.appRefs == ["ig", "tt"] && start.session.blockRef == "b1")
    #expect(start.pass.appRef == "ig" && start.pass.blockRef == "b1" && start.pass.free == true)
  }

  @Test func unblockingABlockWithoutAFreePassWaitsForAllOfIt() {
    let block = BlockDefinition(id: "b1", appRefs: ["ig", "tt"], schedule: .always)
    var state = SharedGateState()
    let events = machine.enter(
      block: block, ledger: ledger(free: 2, waited: 1), state: &state, now: t0, monotonic: boot)
    #expect(events.map(\.kind) == [.waitStarted])
    #expect(events[0].appRef == "ig" && events[0].waitMinutes == 5)
    #expect(state.wait?.appRefs == ["ig", "tt"] && state.wait?.number == 2)
    _ = machine.tick(state: &state, now: t0.addingTimeInterval(300), monotonic: nil)
    #expect(state.pendingPass?.origin == .app && state.pendingPass?.blockRef == "b1")
    #expect(state.pendingPass?.appRefs == ["ig", "tt"])
  }

  @Test func unblockingJoinsARunningWaitAndAPendingPass() {
    let block = BlockDefinition(id: "b1", appRefs: ["ig", "tt"], schedule: .always)
    var state = SharedGateState()
    _ = machine.enter(
      appRef: "yt", ledger: ledger(free: 2, waited: 0), state: &state, now: t0, monotonic: boot)
    #expect(
      machine.enter(
        block: block, ledger: ledger(free: 2, waited: 0), state: &state, now: t0, monotonic: boot
      ).isEmpty)
    #expect(state.wait?.appRefs == ["yt", "ig", "tt"] && state.wait?.startedAt == t0)
    _ = machine.tick(state: &state, now: t0.addingTimeInterval(180), monotonic: nil)
    machine.deferPass(state: &state)
    let other = BlockDefinition(id: "b2", appRefs: ["rd"], schedule: .always)
    #expect(
      machine.enter(block: other, ledger: GateLedger(), state: &state, now: t0, monotonic: boot)
        .isEmpty)
    #expect(state.pendingPass?.appRefs == ["yt", "ig", "tt", "rd"])
    #expect(state.pendingPass?.deferred == false && state.pendingPass?.origin == .shield)
  }

  @Test func blockAgainEndsTheSessionEarly() throws {
    var state = SharedGateState()
    _ = machine.enter(appRef: "ig", ledger: GateLedger(), state: &state, now: t0, monotonic: boot)
    let start = try #require(machine.startSession(minutes: 10, state: &state, now: t0))
    #expect(machine.endSession(UUID(), state: &state) == nil)
    #expect(machine.endSession(start.session.id, state: &state) == start.session)
    #expect(state.sessions.isEmpty)
  }

  @Test func stateWrittenBeforeOriginsStillDecodes() throws {
    let json = """
      {"blocks":[],"sessions":[],"resetHour":4,"notificationsAllowed":false,"unblocks":{},
       "wait":{"id":"7B0E5C1C-3A5E-4E0B-9A3B-0C7B8E4D2F10","appRefs":["ig"],"number":1,"minutes":3,
               "startedAt":1800000000000},
       "pendingPass":{"appRefs":["ig"],"free":true,"waitMinutes":0,"grantedAt":1800000000000}}
      """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    let state = try decoder.decode(SharedGateState.self, from: Data(json.utf8))
    #expect(state.pendingPass?.origin == .shield && state.pendingPass?.deferred == false)
    #expect(state.pendingPass?.blockRef == nil)
    #expect(state.wait?.origin == nil && state.wait?.blockRef == nil)
  }

  @Test func aShortSessionGetsAFifteenMinuteIntervalWithAWarningAtItsEnd() {
    let start = t0.addingTimeInterval(0.7)
    let five = SessionInterval(
      session: ActiveSession(appRefs: ["ig"], minutes: 5, startedAt: start))
    #expect(five.start == start && five.warningMinutes == 10)
    #expect(five.end == t0.addingTimeInterval(901))
    let warning = five.end.addingTimeInterval(-600)
    #expect(warning >= start.addingTimeInterval(300) && warning < start.addingTimeInterval(301))
    let fifteen = SessionInterval(
      session: ActiveSession(appRefs: ["ig"], minutes: 15, startedAt: t0))
    #expect(fifteen.warningMinutes == nil && fifteen.end == t0.addingTimeInterval(900))
    let thirty = SessionInterval(
      session: ActiveSession(appRefs: ["ig"], minutes: 30, startedAt: t0))
    #expect(thirty.warningMinutes == nil && thirty.end == t0.addingTimeInterval(1800))
  }
}
