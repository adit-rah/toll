import Foundation
import Testing

@testable import TollCore

/// A block's line reads without words: each fact carries what its glyph shows (#78, #110).
struct BlockFactsTests {
  func withStudy() -> DuskState {
    var s = setUp(home: false)
    s.blocks[0].appCount = 4
    s.places.append(libraryPlace)
    s.blocks.append(studyBlock())
    arrive(&s, libraryPlace, date(2026, 11, 17, 8))
    return s
  }

  func kinds(_ facts: [BlocksSnapshot.Fact]?) -> [BlocksSnapshot.Fact.Kind] {
    (facts ?? []).map(\.kind)
  }

  @Test func eachFactHasItsGlyph() {
    let blocks = BlocksSnapshot(state: withStudy(), now: date(2026, 11, 17, 19), calendar: london)
    let night = kinds(blocks.night?.facts)
    #expect(night == [.apps, .home])
    let study = kinds(blocks.others.first?.facts)
    #expect(study == [.place, .hours, .days])
    // The words are the facts', in order, so VoiceOver reads what the glyphs show.
    #expect(blocks.others.first?.detail.hasPrefix("Library · 9") == true)
    #expect(blocks.others.first?.facts.last?.text == "Weekdays")
  }

  @Test func theGlyphSaysWhereItReallyRuns() {
    var s = withStudy()
    s.location = .scheduleOnly
    let anywhere = BlocksSnapshot(state: s, now: date(2026, 11, 17, 19), calendar: london)
    let anywhereNight = kinds(anywhere.night?.facts)
    #expect(anywhereNight.contains(.anywhere))
    #expect(anywhere.others.first?.facts.first == .init(.anywhere, "Anywhere"))
    s.blocks[1].onlyAtPlace = true
    let waiting = BlocksSnapshot(state: s, now: date(2026, 11, 17, 19), calendar: london)
    #expect(waiting.others.first?.facts.first?.kind == .waiting)
  }

  @Test func theNightSaysWhenWeekendsDiffer() {
    var s = withStudy()
    s.blocks[0].schedule = WeeklySchedule(rules: [
      .init(days: Weekday.schoolNights, window: usual),
      .init(days: Weekday.weekendNights, window: TimeWindow(start: time(23, 30), end: time(9))),
    ])
    let night = BlocksSnapshot(state: s, now: date(2026, 11, 17, 12), calendar: london).night
    #expect(night?.facts.last?.kind == .weekendsDiffer)
  }

  @Test func aHeldChangeIsTheOneFact() {
    var s = withStudy()
    run(&s, date(2026, 11, 17, 10))
    _ = apply(.deleteBlock(BlockID("study")), &s, date(2026, 11, 17, 10))
    let deleting = BlocksSnapshot(state: s, now: date(2026, 11, 17, 10), calendar: london)
    let held = kinds(deleting.others.first?.facts)
    #expect(held == [.deleting])
    var edited = withStudy()
    run(&edited, date(2026, 11, 17, 10))
    var study = studyBlock()
    study.name = "Library"
    _ = apply(.saveBlock(study), &edited, date(2026, 11, 17, 10))
    let changing = BlocksSnapshot(state: edited, now: date(2026, 11, 17, 10), calendar: london)
    let edit = kinds(changing.others.first?.facts)
    #expect(edit == [.changing])
  }
}

/// The editor's hours say how long they are; the night's, with the minutes locked around it.
struct HoursLengthTests {
  @Test func theLengthIsSaid() {
    #expect(Copy.Blocks.length(minutes: 480) == "8 h")
    #expect(
      Copy.Blocks.nightLength(minutes: 510, before: 30, after: 15)
        == "8 h 30 m asleep · 30 min before sleep · 15 min after waking")
    #expect(Copy.Blocks.nightLength(minutes: 510, before: 0, after: 0) == "8 h 30 m asleep")
  }
}

/// Past `blocks.foldAbove` other blocks fold into one row, which opens by itself while one is on
/// (#110).
struct BlockGroupTests {
  func with(others count: Int) -> DuskState {
    var s = setUp(home: false)
    s.places.append(libraryPlace)
    s.blocks.append(studyBlock())
    arrive(&s, libraryPlace, date(2026, 11, 17, 8))
    for index in 1..<count {
      var gym = BlockDraft.new(.gym)
      gym.id = BlockID("gym\(index)")
      gym.appCount = 1
      s.blocks.append(gym)
    }
    return s
  }

  @Test func afewStayAsRows() {
    let s = with(others: 3)
    #expect(BlocksSnapshot(state: s, now: date(2026, 11, 17, 19), calendar: london).group == nil)
  }

  @Test func moreFoldIntoOneRow() {
    let s = with(others: 4)
    let blocks = BlocksSnapshot(state: s, now: date(2026, 11, 17, 19, 30), calendar: london)
    #expect(blocks.group?.title == "4 other blocks")
    #expect(blocks.group?.kinds == [.study, .gym, .gym, .gym])
    #expect(blocks.group?.onNow == nil)
    #expect(blocks.group?.opensByItself == false)
    // The rows are still there for when it opens.
    #expect(blocks.others.count == 4)
  }

  @Test func itOpensByItselfWhileOneIsOn() {
    var s = with(others: 4)
    run(&s, date(2026, 11, 17, 10))
    let blocks = BlocksSnapshot(state: s, now: date(2026, 11, 17, 10), calendar: london)
    #expect(blocks.group?.onNow?.hasPrefix("Study on until 5") == true)
    #expect(blocks.group?.opensByItself == true)
  }

  @Test func theThresholdIsConfig() {
    var config = TollConfig.defaults
    config.blocks.foldAbove = 1
    let s = with(others: 2)
    let blocks = BlocksSnapshot(
      state: s, now: date(2026, 11, 17, 19), calendar: london, config: config)
    #expect(blocks.group?.title == "2 other blocks")
  }
}
