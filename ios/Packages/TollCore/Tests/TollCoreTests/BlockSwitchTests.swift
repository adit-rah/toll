import Foundation
import Testing

@testable import TollCore

/// #161, the founder's "yes, but not during the block": another block can be switched off outside
/// its hours and on at any time, inside them from its next start (B-3, B-4). The night has no
/// switch. Study runs 9 am – 5 pm on weekdays; 17 Nov 2026 is a Tuesday.
struct BlockSwitchTests {
  let study = BlockID("study")

  func state() -> DuskState {
    var state = setUp()
    state.setupFinishedAt = date(2026, 11, 10, 12)
    state.trial.purchased = true
    state.blocks.append(
      Block(
        id: study, name: "Study", kind: .study, place: nil,
        schedule: WeeklySchedule(rules: [
          .init(days: Weekday.weekdays, window: TimeWindow(start: time(9), end: time(17)))
        ]), apps: Data([1]), appCount: 2))
    return state
  }

  func switched(_ state: DuskState, on: Bool) -> Block {
    var block = state.block(study) ?? state.blocks[0]
    block.isOn = on
    return block
  }

  @Test func offOutsideItsHoursAppliesAtOnce() {
    var s = state()
    run(&s, date(2026, 11, 17, 18))
    #expect(apply(.saveBlock(switched(s, on: false)), &s, date(2026, 11, 17, 18)) == nil)
    #expect(s.block(study)?.isOn == false)
    // Nothing locks on its hours while it's off.
    run(&s, date(2026, 11, 18, 10))
    #expect(s.runtime.active[study] == nil)
  }

  /// Inside its hours the switch holds, whether or not the block is locking right now: off is
  /// never a way out of a block that's on.
  @Test func offIsRefusedInsideItsHours() {
    var s = state()
    run(&s, date(2026, 11, 17, 10))
    #expect(s.runtime.active[study] != nil)
    #expect(
      apply(.saveBlock(switched(s, on: false)), &s, date(2026, 11, 17, 10)) == .cannotSwitchOff)
    #expect(s.block(study)?.isOn == true)
    #expect(s.pending[study] == nil)
    let facts = BlockSwitch(
      s.block(study) ?? s.blocks[0], now: date(2026, 11, 17, 10), calendar: london)
    #expect(facts?.canTurnOff == false)
    #expect(facts?.offAfter == date(2026, 11, 17, 17))
    let after = BlockSwitch(
      s.block(study) ?? s.blocks[0], now: date(2026, 11, 17, 17), calendar: london)
    #expect(after?.canTurnOff == true)
  }

  /// On inside its hours: saved at once, but the hours it's in count as ended (B-4), so it first
  /// locks at the next start rather than mid-way.
  @Test func onInsideItsHoursWaitsForTheNextStart() {
    var s = state()
    s.blocks[1].isOn = false
    run(&s, date(2026, 11, 17, 10))
    let facts = BlockSwitch(s.blocks[1], now: date(2026, 11, 17, 10), calendar: london)
    #expect(facts?.startsAt == date(2026, 11, 18, 9))
    #expect(apply(.saveBlock(switched(s, on: true)), &s, date(2026, 11, 17, 10)) == nil)
    #expect(s.block(study)?.isOn == true)
    run(&s, date(2026, 11, 17, 10, 5))
    #expect(s.runtime.active[study] == nil)
    run(&s, date(2026, 11, 18, 9, 5))
    #expect(s.runtime.active[study] == date(2026, 11, 18, 17))
  }

  @Test func onOutsideItsHoursLocksAtItsStart() {
    var s = state()
    s.blocks[1].isOn = false
    #expect(apply(.saveBlock(switched(s, on: true)), &s, date(2026, 11, 17, 8)) == nil)
    #expect(BlockSwitch(s.blocks[1], now: date(2026, 11, 17, 8), calendar: london)?.startsAt == nil)
    run(&s, date(2026, 11, 17, 9, 5))
    #expect(s.runtime.active[study] == date(2026, 11, 17, 17))
  }

  @Test func theNightHasNoSwitch() {
    var s = state()
    #expect(BlockSwitch(s.blocks[0], now: date(2026, 11, 17, 15), calendar: london) == nil)
    var night = s.blocks[0]
    night.isOn = false
    #expect(apply(.saveBlock(night), &s, date(2026, 11, 17, 15)) == .cannotSwitchOff)
    #expect(s.blocks[0].isOn)
  }

  /// Blocks says it with a shape as well as a word: off is its own state.
  @Test func anOffBlocksRowSaysOff() {
    var s = state()
    s.blocks[1].isOn = false
    let row = BlocksSnapshot(state: s, now: date(2026, 11, 17, 10), calendar: london).others[0]
    #expect(row.state == .off)
    #expect(row.stateText == Copy.Home.off)
  }
}
