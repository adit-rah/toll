import Foundation
import Testing

@testable import TollCore

/// Other blocks are quick to add and change (#89, #62): a kind brings a name and hours.
struct BlockDraftTests {
  func rule(_ block: Block) -> WeeklySchedule.Rule? { block.schedule.rules.first }

  @Test func eachKindStartsWithItsHours() {
    let study = BlockDraft.new(.study)
    #expect(study.name == "Study")
    #expect(study.place == nil && study.apps == nil)
    #expect(rule(study)?.window == TimeWindow(start: time(9), end: time(17)))
    #expect(rule(study)?.days == Weekday.weekdays)
    #expect(rule(BlockDraft.new(.work))?.window == TimeWindow(start: time(9), end: time(17)))
    let gym = BlockDraft.new(.gym)
    #expect(gym.name == "Gym")
    #expect(rule(gym)?.window == TimeWindow(start: time(18), end: time(19)))
    #expect(BlockDraft.new(.other).schedule.isValid)
    #expect(BlockDraft.kinds == [.study, .work, .gym, .other])
  }

  @Test func theHoursComeFromConfig() {
    var config = TollConfig.defaults
    config.blocks.gym = TollConfig.Hours(start: time(7), end: time(8), days: [.saturday])
    let gym = BlockDraft.new(.gym, config: config)
    #expect(rule(gym)?.window == TimeWindow(start: time(7), end: time(8)))
    #expect(rule(gym)?.days == [.saturday])
  }

  /// The defaults share one time window, so adding them doesn't use up the eight (D40).
  @Test func theDefaultsShareAWindow() {
    var s = setUp()
    s.blocks += [BlockDraft.new(.study), BlockDraft.new(.work), BlockDraft.new(.other)]
    #expect(BlockLimits(state: s).windowsUsed == 2)
  }

  @Test func changingKindKeepsWhatTheUserChose() {
    let study = BlockDraft.new(.study)
    let gym = BlockDraft.change(study, to: .gym)
    #expect(gym.kind == .gym && gym.name == "Gym" && gym.id == study.id)
    #expect(rule(gym)?.window == TimeWindow(start: time(18), end: time(19)))

    var named = BlockDraft.new(.study)
    named.name = "Library"
    named.schedule.rules[0].window.end = time(18)
    let work = BlockDraft.change(named, to: .work)
    #expect(work.kind == .work)
    #expect(work.name == "Library")
    #expect(rule(work)?.window.end == time(18))
  }

  @Test func theNightNeverChangesKind() {
    let night = sleepBlock()
    #expect(BlockDraft.change(night, to: .study) == night)
    #expect(BlockDraft.change(BlockDraft.new(.work), to: .sleep).kind == .work)
  }

  @Test func namesAreShortAndNotBlank() {
    #expect(BlockDraft.isValidName("Library"))
    #expect(!BlockDraft.isValidName(""))
    #expect(!BlockDraft.isValidName("   "))
    let long = String(repeating: "a", count: 25)
    #expect(!BlockDraft.isValidName(long))
    #expect(BlockDraft.name(long).count == 24)
    #expect(BlockDraft.isValidName(BlockDraft.name(long)))
    var padded = BlockDraft.new(.study)
    padded.name = "  Café "
    #expect(BlockDraft.finished(padded).name == "Café")
  }

  @Test func homeIsWhereTheNightIs() {
    var s = setUp()
    s.places.append(libraryPlace)
    #expect(s.isHome(homePlace.id))
    #expect(!s.isHome(libraryPlace.id))
    #expect(!s.isHome(nil))
    s.blocks[0].place = nil
    #expect(!s.isHome(homePlace.id))
  }

  @Test func theEngineRefusesABadName() {
    var s = setUp()
    var block = BlockDraft.new(.study)
    block.apps = Data([2])
    block.name = " "
    #expect(apply(.saveBlock(block), &s, date(2026, 11, 17, 12)) == .invalidName)
    block.name = String(repeating: "a", count: 25)
    #expect(apply(.saveBlock(block), &s, date(2026, 11, 17, 12)) == .invalidName)
    block.name = "Café"
    #expect(apply(.saveBlock(block), &s, date(2026, 11, 17, 12)) == nil)
    #expect(s.block(block.id)?.name == "Café")
  }
}

/// Tonight is about the night (D68): another block is one quiet line, and only while it's on.
struct TonightOtherBlocksTests {
  func withStudy() -> DuskState {
    var s = setUp()
    s.places.append(libraryPlace)
    s.blocks.append(studyBlock())
    arrive(&s, libraryPlace, date(2026, 11, 17, 8))
    return s
  }

  @Test func aDayBlockIsALineNotTheHero() {
    var s = withStudy()
    run(&s, date(2026, 11, 17, 10))
    let home = HomeSnapshot(state: s, log: [], now: date(2026, 11, 17, 10), calendar: london)
    guard case .tonight(let start, _) = home.hero else {
      Issue.record("The night keeps the hero: \(home.hero)")
      return
    }
    #expect(start == date(2026, 11, 17, 22, 30))
    #expect(home.otherBlock?.text.hasPrefix("Study on until 5") == true)
    #expect(home.otherBlock?.kind == .study)
    #expect(home.otherBlock?.offersPause == true)
    // The strip has both: Study on now, the night later and drawn as the night (D75).
    #expect(home.timeline?.segments.map(\.kind) == [.study, .sleep])
    #expect(home.timeline?.segments.map(\.state) == [.on, .later])
  }

  @Test func nothingWhileNoOtherBlockIsOn() {
    var s = withStudy()
    run(&s, date(2026, 11, 17, 19))
    #expect(
      HomeSnapshot(state: s, log: [], now: date(2026, 11, 17, 19), calendar: london).otherBlock
        == nil)
  }

  @Test func underTheNightItLeavesThePauseToTheHero() {
    var s = withStudy()
    var late = studyBlock()
    late.id = BlockID("late")
    late.name = "Late"
    late.place = nil
    late.schedule = .everyDay(TimeWindow(start: time(22), end: time(23, 30)))
    s.blocks.append(late)
    run(&s, date(2026, 11, 17, 23))
    let home = HomeSnapshot(state: s, log: [], now: date(2026, 11, 17, 23), calendar: london)
    guard case .blocked = home.hero else {
      Issue.record("The night is on: \(home.hero)")
      return
    }
    #expect(home.otherBlock?.text.hasPrefix("Late on until 11:30") == true)
    #expect(home.otherBlock?.offersPause == false)
  }

  @Test func severalOnAreCounted() {
    var s = withStudy()
    var work = BlockDraft.new(.work)
    work.schedule = WeeklySchedule(rules: [
      .init(days: Weekday.weekdays, window: TimeWindow(start: time(9), end: time(18)))
    ])
    s.blocks.append(work)
    run(&s, date(2026, 11, 17, 10))
    let line = HomeSnapshot(state: s, log: [], now: date(2026, 11, 17, 10), calendar: london)
      .otherBlock
    #expect(line?.text.hasPrefix("2 blocks on until 6") == true)
    #expect(line?.kind == .work)
  }

  @Test func noLineWithoutScreenTime() {
    var s = withStudy()
    s.setupFinishedAt = date(2026, 11, 13, 20)
    run(&s, date(2026, 11, 17, 10))
    let home = HomeSnapshot(
      state: s, log: [], now: date(2026, 11, 17, 10), calendar: london, screenTime: false)
    #expect(home.otherBlock == nil)
  }
}
