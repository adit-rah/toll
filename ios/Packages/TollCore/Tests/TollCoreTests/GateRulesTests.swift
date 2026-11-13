import Foundation
import Testing

@testable import TollCore

struct GateRulesTests {
  let gate = TollConfig.Gate()
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  func pass(free: Bool, app: AppRef = "a") -> GateEvent {
    GateEvent(kind: .pass, occurredAt: t0, tzOffsetMinutes: 0, appRef: app, free: free)
  }

  @Test func waitLadderCapsAtTheLastValue() {
    #expect(
      (0...5).map { GateRules.waitMinutes(afterWaitedPasses: $0, config: gate) } == [
        3, 5, 8, 8, 8, 8,
      ])
  }

  @Test func freePassesComeFirst() {
    let ledger = GateLedger(eventsOfToday: [pass(free: true)])
    #expect(GateRules.entry(ledger: ledger, runningWait: nil, config: gate) == .freePass)
  }

  @Test func afterFreePassesTheLadderStarts() {
    let ledger = GateLedger(eventsOfToday: [pass(free: true), pass(free: true), pass(free: false)])
    #expect(ledger.freePasses == 2 && ledger.waitedPasses == 1)
    #expect(
      GateRules.entry(ledger: ledger, runningWait: nil, config: gate)
        == .startWait(minutes: 5, number: 2))
    #expect(GateRules.nextWaitMinutes(forWaitNumber: 2, config: gate) == 8)
  }

  @Test func aHitDuringAWaitJoinsIt() {
    let wait = Wait(appRef: "a", number: 1, minutes: 3, startedAt: t0, startedMonotonic: nil)
    #expect(GateRules.entry(ledger: GateLedger(), runningWait: wait, config: gate) == .joinWait)
  }

  @Test func passesAreCountedPerAppForTheShieldSubtitle() {
    var both = pass(free: false)
    both.appRefs = ["a", "b"]
    let ledger = GateLedger(eventsOfToday: [pass(free: true), both])
    #expect(ledger.passesByApp == ["a": 2, "b": 1])
  }

  @Test func heldMeansNoWaitAndNoFreePassWithinTheWindow() {
    let hit = GateEvent(kind: .blockHit, occurredAt: t0, tzOffsetMinutes: 0, appRef: "a")
    let wait = GateEvent(
      kind: .waitStarted, occurredAt: t0.addingTimeInterval(30), tzOffsetMinutes: 0)
    let late = GateEvent(
      kind: .waitStarted, occurredAt: t0.addingTimeInterval(121), tzOffsetMinutes: 0)
    var free = pass(free: true)
    free.occurredAt = t0.addingTimeInterval(5)
    #expect(GateRules.isHeld(hit: hit, following: [], window: 120))
    #expect(!GateRules.isHeld(hit: hit, following: [wait], window: 120))
    #expect(!GateRules.isHeld(hit: hit, following: [free], window: 120))
    #expect(GateRules.isHeld(hit: hit, following: [late], window: 120))
  }

  @Test func aFreePassOfferedAndDeclinedLeavesTheHitHeld() throws {
    let machine = GateMachine(config: gate, timeZone: TimeZone(identifier: "UTC") ?? .gmt)
    let hit = GateEvent(kind: .blockHit, occurredAt: t0, tzOffsetMinutes: 0, appRef: "a")
    var state = SharedGateState()
    let offered = machine.enter(
      appRef: "a", ledger: GateLedger(), state: &state, now: t0, monotonic: nil)
    #expect(GateRules.isHeld(hit: hit, following: offered, window: 120))
    let used = try #require(
      machine.startSession(minutes: 5, state: &state, now: t0.addingTimeInterval(20)))
    #expect(!GateRules.isHeld(hit: hit, following: [used.pass], window: 120))
  }

  @Test func blockLimits() {
    let blocks = TollConfig.Blocks()
    #expect(BlockLimits.canAddBlock(existing: 7, config: blocks))
    #expect(!BlockLimits.canAddBlock(existing: 8, config: blocks))
    #expect(BlockLimits.fits(tokenCount: 10, otherBlocksTokenCount: 30, config: blocks))
    #expect(!BlockLimits.fits(tokenCount: 11, otherBlocksTokenCount: 30, config: blocks))
  }
}
