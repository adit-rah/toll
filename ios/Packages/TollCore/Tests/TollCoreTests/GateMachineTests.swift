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

  @Test func freePassIsRecordedAtOnceAndOpensThePicker() {
    var state = SharedGateState()
    let events = machine.enter(
      appRef: "ig", ledger: GateLedger(), state: &state, now: t0, monotonic: boot)
    #expect(events.map(\.kind) == [.pass])
    #expect(events[0].free == true)
    #expect(state.pendingPass?.appRefs == ["ig"])
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

  @Test func theWaitCompletesIntoAWaitedPassForEveryJoinedApp() {
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
    #expect(events.map(\.kind) == [.waitCompleted, .pass])
    #expect(
      events[1].free == false && events[1].waitMinutes == 3 && events[1].appRefs == ["ig", "tt"])
    #expect(state.wait == nil && state.pendingPass?.appRefs == ["ig", "tt"])
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

  @Test func sessionUnlocksThePendingAppsUntilTheWindowEnds() throws {
    var state = SharedGateState()
    _ = machine.enter(appRef: "ig", ledger: GateLedger(), state: &state, now: t0, monotonic: boot)
    let session = try #require(machine.startSession(minutes: 10, state: &state, now: t0))
    #expect(session.appRefs == ["ig"] && session.minutes == 10)
    #expect(session.expiresAt == t0.addingTimeInterval(3600))
    #expect(state.pendingPass == nil && state.sessions.count == 1 && state.lastSessionMinutes == 10)
    #expect(machine.startSession(minutes: 5, state: &state, now: t0) == nil)
    #expect(machine.sessionEnded(session, at: t0).sessionMinutes == 10)
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
}
