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
    let max = TollConfig.defaults.blocks.max
    for hour in 0..<(max + 1) {
      let block = Block(
        name: "B\(hour)", kind: .other, place: nil,
        schedule: .everyDay(TimeWindow(start: time(hour), end: time(hour, 30))), apps: nil)
      let result = apply(.saveBlock(block), &many, date(2026, 11, 17, 8))
      #expect(result == (hour < max - 1 ? nil : .tooManyBlocks))
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
      Engine.apply(
        .saveBlock(first), to: &s, now: date(2026, 11, 17, 8), calendar: london, config: config)
        == nil)
    #expect(
      Engine.apply(
        .saveBlock(second), to: &s, now: date(2026, 11, 17, 8), calendar: london, config: config)
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

struct BlockLimitsTests {
  @Test func appsAndSitesCountCategoriesDoNot() {
    var s = setUp()
    s.blocks[0].appCount = 4
    s.blocks[0].categoryCount = 2
    var study = studyBlock()
    study.appCount = 3
    study.categoryCount = 5
    let limits = BlockLimits(state: s, draft: study)
    #expect(limits.appsUsed == 7)
    #expect(limits.appsOver == 0)
  }

  @Test func blocksWithTheSameHoursShareAWindow() {
    var s = setUp()
    s.blocks.append(studyBlock())
    var twin = studyBlock()
    twin.id = BlockID("twin")
    s.blocks.append(twin)
    let limits = BlockLimits(state: s)
    #expect(limits.windowsUsed == 2)
    #expect(limits.canAddBlock)
  }

  @Test func eightWindowsTurnNewBlockOff() {
    var s = setUp()
    for hour in 8..<15 {
      var block = studyBlock()
      block.id = BlockID("b\(hour)")
      block.schedule = .everyDay(
        TimeWindow(start: ClockTime(hour: hour), end: ClockTime(hour: hour, minute: 30)))
      s.blocks.append(block)
    }
    let limits = BlockLimits(state: s)
    #expect(limits.windowsUsed == 8)
    #expect(!limits.canAddBlock)
  }
}

struct BlocksSnapshotTests {
  @Test func rowsSayWhatEachBlockHoldsAndWhichIsOn() {
    var s = setUp(home: false)
    s.blocks[0].appCount = 4
    s.places.append(libraryPlace)
    s.blocks.append(studyBlock())
    arrive(&s, libraryPlace, date(2026, 11, 17, 9))
    run(&s, date(2026, 11, 17, 10))
    let blocks = BlocksSnapshot(state: s, now: date(2026, 11, 17, 10), calendar: london)
    // The night leads on its own, never as a row called "Sleep" (D68).
    #expect(blocks.night?.detail == "4 apps · Home")
    #expect(blocks.night?.picture?.start.contains("10:30") == true)
    #expect(blocks.night?.state == .later)
    #expect(blocks.night?.stateText == "Tonight")
    #expect(blocks.others.map(\.id) == [BlockID("study")])
    #expect(blocks.others[0].state == .on)
    #expect(blocks.others[0].stateText == "On now")
    #expect(blocks.others[0].detail.hasPrefix("Library · 9"))
    #expect(blocks.others[0].detail.hasSuffix("· Weekdays"))
  }

  @Test func laterRowsNameTheirDay() {
    var s = setUp()
    s.places.append(libraryPlace)
    s.blocks.append(studyBlock())
    // Saturday noon: Study is Monday's.
    let saturday = BlocksSnapshot(state: s, now: date(2026, 11, 21, 12), calendar: london)
    #expect(saturday.night?.stateText == "Tonight")
    #expect(saturday.others[0].stateText == "Mon")
    #expect(saturday.others[0].state == .later)
    // Thursday evening: Study is tomorrow, not today.
    let thursday = BlocksSnapshot(state: s, now: date(2026, 11, 19, 18), calendar: london)
    #expect(thursday.others[0].stateText == "Fri")
    let friday = BlocksSnapshot(state: s, now: date(2026, 11, 20, 7), calendar: london)
    #expect(friday.others[0].stateText == "Today")
  }

  @Test func theNightSaysWhenWeekendsDiffer() {
    var s = setUp()
    s.blocks[0].schedule = WeeklySchedule(rules: [
      .init(days: Weekday.schoolNights, window: usual),
      .init(days: Weekday.weekendNights, window: TimeWindow(start: time(23, 30), end: time(9))),
    ])
    let night = BlocksSnapshot(state: s, now: date(2026, 11, 17, 12), calendar: london).night
    #expect(night?.detail.hasSuffix("· Weekends differ") == true)
  }
}

/// What the rows say when a block doesn't run as its place suggests, or a change waits (#49).
struct BlockRowsTests {
  func withStudy() -> DuskState {
    var s = setUp(home: false)
    s.places.append(libraryPlace)
    s.blocks.append(studyBlock())
    arrive(&s, libraryPlace, date(2026, 11, 17, 8))
    return s
  }

  @Test func withoutLocationAPlacedBlockSaysAnywhere() {
    var s = withStudy()
    s.location = .scheduleOnly
    let blocks = BlocksSnapshot(state: s, now: date(2026, 11, 17, 8), calendar: london)
    #expect(blocks.night?.detail.contains("Anywhere") == true)
    #expect(blocks.others.allSatisfy { $0.detail.hasPrefix("Anywhere") })
    #expect(!blocks.others.contains { $0.detail.contains("Library") })
  }

  @Test func aHeldDeleteOrEditIsOnTheRow() {
    var s = withStudy()
    run(&s, date(2026, 11, 17, 10))
    _ = apply(.deleteBlock(BlockID("study")), &s, date(2026, 11, 17, 10))
    let row = BlocksSnapshot(state: s, now: date(2026, 11, 17, 10), calendar: london).others
      .first { $0.id == BlockID("study") }
    #expect(row?.detail.hasPrefix("Deleted at 5") == true)
    #expect(row?.state == .on)
    var edited = withStudy()
    run(&edited, date(2026, 11, 17, 10))
    var study = studyBlock()
    study.name = "Library"
    _ = apply(.saveBlock(study), &edited, date(2026, 11, 17, 10))
    let blocks = BlocksSnapshot(state: edited, now: date(2026, 11, 17, 10), calendar: london)
    #expect(blocks.others.first?.detail.hasPrefix("Changes apply at 5") == true)
  }
}

/// Without Always, a block tied to a place runs anywhere or waits, as the user chose (#63).
struct OnlyAtPlaceTests {
  @Test func aBlockCanWaitForAlways() {
    var s = setUp(home: false)
    s.location = .scheduleOnly
    s.places.append(libraryPlace)
    var study = studyBlock()
    study.onlyAtPlace = true
    s.blocks.append(study)
    run(&s, date(2026, 11, 17, 10))
    #expect(!s.isBlocking)
    #expect(Engine.waitsForAlways(study, s))
    s.blocks[1].onlyAtPlace = false
    run(&s, date(2026, 11, 17, 10, 1))
    #expect(s.activeBlocks.map(\.id) == [BlockID("study")])
  }

  @Test func sleepIgnoresItAndAlwaysRunsOnItsHours() {
    var s = setUp(home: false)
    s.location = .scheduleOnly
    s.blocks[0].onlyAtPlace = true
    run(&s, date(2026, 11, 17, 23))
    #expect(s.activeBlocks.map(\.id) == [BlockID("sleep")])
    #expect(!Engine.waitsForAlways(s.blocks[0], s))
  }
}
