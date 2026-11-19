import Foundation
import Testing

@testable import TollCore

/// Several blocks at once (D29): each by its own place and hours, the shield their union.
struct BlocksTests {
  func withStudy(atLibrary: Bool = true) -> DuskState {
    var s = setUp(home: false)
    s.places.append(libraryPlace)
    s.blocks.append(studyBlock())
    arrive(&s, libraryPlace, date(2026, 11, 17, 8), inside: atLibrary)
    return s
  }

  @Test func eachBlockByItsOwnPlaceAndHours() {
    var s = withStudy()
    // Tuesday 10:00 at the library.
    let effects = run(&s, date(2026, 11, 17, 10))
    #expect(s.activeBlocks.map(\.id) == [BlockID("study")])
    #expect(effects.shield.selections == [Data([2])])
    // Saturday 10:00: not a weekday.
    var weekend = withStudy()
    run(&weekend, date(2026, 11, 21, 10))
    #expect(!weekend.isBlocking)
  }

  @Test func overlappingBlocksShieldTheirUnion() {
    var s = withStudy()
    s.blocks[0].schedule = .everyDay(TimeWindow(start: time(8), end: time(23)))
    s.blocks[0].place = nil
    let effects = run(&s, date(2026, 11, 17, 10))
    #expect(Set(effects.shield.selections) == [Data([1]), Data([2])])
  }

  @Test func leavingOnePlaceEndsOnlyItsBlock() {
    var s = withStudy()
    s.blocks[0].schedule = .everyDay(TimeWindow(start: time(8), end: time(23)))
    s.blocks[0].place = nil
    run(&s, date(2026, 11, 17, 10))
    arrive(&s, libraryPlace, date(2026, 11, 17, 11), inside: false)
    let effects = run(&s, date(2026, 11, 17, 11), .left)
    #expect(s.activeBlocks.map(\.id) == [BlockID("sleep")])
    #expect(effects.shield.selections == [Data([1])])
  }

  @Test func aBlockWithoutAPlaceRunsAnywhere() {
    var s = setUp(home: false)
    var gym = studyBlock()
    gym.id = BlockID("gym")
    gym.place = nil
    #expect(apply(.saveBlock(gym), &s, date(2026, 11, 17, 8)) == nil)
    run(&s, date(2026, 11, 17, 10))
    #expect(s.activeBlocks.map(\.id) == [BlockID("gym")])
  }

  @Test func theSleepBlockCannotBeDeleted() {
    var s = setUp()
    #expect(
      apply(.deleteBlock(BlockID("sleep")), &s, date(2026, 11, 17, 8)) == .sleepBlockCannotBeDeleted
    )
  }

  @Test func deletingAnActiveBlockWaitsUntilItEnds() {
    var s = withStudy()
    run(&s, date(2026, 11, 17, 10))
    #expect(apply(.deleteBlock(BlockID("study")), &s, date(2026, 11, 17, 10)) == nil)
    #expect(s.block(BlockID("study")) != nil)
    run(&s, date(2026, 11, 17, 17), .windowEnd)
    #expect(s.block(BlockID("study")) == nil)
  }

  @Test func limits() {
    var s = setUp()
    var greedy = studyBlock()
    greedy.place = nil
    greedy.appCount = 37
    #expect(apply(.saveBlock(greedy), &s, date(2026, 11, 17, 8)) == .tooManyApps)
    greedy.appCount = 36
    #expect(apply(.saveBlock(greedy), &s, date(2026, 11, 17, 8)) == nil)

    var unknown = studyBlock()
    unknown.id = BlockID("x")
    unknown.appCount = 0
    #expect(apply(.saveBlock(unknown), &s, date(2026, 11, 17, 8)) == .unknownPlace)

    var second = sleepBlock()
    second.id = BlockID("sleep2")
    #expect(apply(.saveBlock(second), &s, date(2026, 11, 17, 8)) == .noSleepBlock)

    var many = setUp()
    for hour in 0..<7 {
      let block = Block(
        name: "B\(hour)", kind: .other, place: nil,
        schedule: .everyDay(TimeWindow(start: time(hour), end: time(hour, 30))), apps: nil)
      let result = apply(.saveBlock(block), &many, date(2026, 11, 17, 8))
      #expect(result == (hour < 5 ? nil : .tooManyBlocks))
    }
  }

  @Test func tooManyWindows() {
    var s = setUp()
    var config = TollConfig.defaults
    config.blocks.maxWindows = 2
    let first = Block(
      name: "A", kind: .other, place: nil,
      schedule: .everyDay(TimeWindow(start: time(9), end: time(10))), apps: nil)
    let second = Block(
      name: "B", kind: .other, place: nil,
      schedule: .everyDay(TimeWindow(start: time(11), end: time(12))), apps: nil)
    #expect(
      Engine.apply(.saveBlock(first), to: &s, now: date(2026, 11, 17, 8), config: config) == nil)
    #expect(
      Engine.apply(.saveBlock(second), to: &s, now: date(2026, 11, 17, 8), config: config)
        == .tooManyWindows)
  }

  @Test func switchedOffBlocksAreNotScheduled() {
    var s = withStudy()
    s.blocks[1].isOn = false
    #expect(run(&s, date(2026, 11, 17, 10)).windows == [usual])
    #expect(!s.isBlocking)
  }

  @Test func eachBlockHasItsOwnLastEnd() {
    var s = withStudy()
    run(&s, date(2026, 11, 17, 18))
    #expect(s.runtime.lastEnd[BlockID("study")] == date(2026, 11, 17, 17))
    #expect(s.runtime.lastEnd[BlockID("sleep")] == date(2026, 11, 17, 7))
  }

  @Test func withoutLocationEveryBlockRunsOnItsHours() {
    var s = withStudy(atLibrary: false)
    s.location = .scheduleOnly
    run(&s, date(2026, 11, 17, 10))
    #expect(s.activeBlocks.map(\.id) == [BlockID("study")])
  }
}
