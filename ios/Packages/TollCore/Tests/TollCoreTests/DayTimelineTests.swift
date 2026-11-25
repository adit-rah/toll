import Foundation
import Testing

@testable import TollCore

/// Tonight's strip is the whole day (D75): from the night's end to the same time the next day, the
/// night never split, every other block drawn apart, now always on it, and every segment big enough
/// to tap.
struct DayTimelineTests {
  func plain(_ text: String?) -> String? { text?.replacingOccurrences(of: "\u{202F}", with: " ") }

  func day(_ state: DuskState, _ now: Date, blocking: Bool = true) -> DayTimeline {
    DayTimeline(state: state, now: now, calendar: london, blocking: blocking)
  }

  func withStudy() -> DuskState {
    var s = setUp()
    s.places.append(libraryPlace)
    s.blocks.append(studyBlock())
    return s
  }

  // MARK: The day it covers

  @Test func theEveningRunsFromThisMorningsWakeToTomorrows() {
    let strip = day(setUp(), date(2026, 11, 17, 19, 18))
    #expect(strip.start == date(2026, 11, 17, 7))
    #expect(strip.end == date(2026, 11, 18, 7))
    let now: Double = (12 + 18.0 / 60) / 24
    #expect(abs(strip.now - now) < 1e-9)
    #expect(strip.segments.count == 1)
    #expect(strip.segments.first?.start == 15.5 / 24)
    #expect(strip.segments.first?.end == 1)
    // Every six hours on the clock, none against an edge: 6 am tomorrow is too close to it.
    #expect(strip.hours.map { plain($0.label) } == ["12 pm", "6 pm", "12 am"])
    let at: [Double] = [5, 11, 17].map { $0 / 24 }
    #expect(strip.hours.map(\.at) == at)
    #expect(plain(strip.nowLabel) == "Now, 7:18 pm")
  }

  @Test func inTheNightTheDayEndsWithIt() {
    var s = setUp()
    run(&s, date(2026, 11, 18, 2))
    let strip = day(s, date(2026, 11, 18, 2))
    #expect(strip.start == date(2026, 11, 17, 7))
    #expect(strip.end == date(2026, 11, 18, 7))
    #expect(strip.now == 19.0 / 24)
    #expect(strip.segments.map(\.state) == [.on])
  }

  /// The founder's 1:19 pm – 7:49 am seen at 9:44 am (#82): the whole night and now both fit.
  @Test func anyHoursFit() {
    var s = setUp()
    s.blocks[0].schedule = .everyDay(TimeWindow(start: time(13, 19), end: time(7, 49)))
    let strip = day(s, date(2026, 11, 21, 9, 44))
    #expect(strip.start == date(2026, 11, 21, 7, 49))
    #expect(strip.now > 0 && strip.now < (strip.segments.first?.start ?? 0))
    #expect(strip.segments.first?.end == 1)
  }

  /// A weekday night seen at the weekend isn't drawn as today's: the day starts at the last wake,
  /// or at the next night's wake time when there was none in the last day.
  @Test func aNightDaysAwayLeavesTheStripToToday() {
    var s = setUp()
    s.blocks[0].schedule = WeeklySchedule(rules: [.init(days: Weekday.weekdays, window: usual)])
    let saturday = day(s, date(2026, 11, 21, 15))
    #expect(saturday.start == date(2026, 11, 21, 7))
    #expect(saturday.segments.isEmpty)
    let sunday = day(s, date(2026, 11, 22, 15))
    #expect(sunday.start == date(2026, 11, 22, 7))
    #expect(sunday.end == date(2026, 11, 23, 7))
    #expect(
      HomeSnapshot(state: s, log: [], now: date(2026, 11, 22, 15), calendar: london).timeline
        == nil)
  }

  @Test func withNoNightItsMidnightToMidnight() {
    let strip = day(DuskState(), date(2026, 11, 17, 15))
    #expect(strip.start == date(2026, 11, 17, 0))
    #expect(strip.end == date(2026, 11, 18, 0))
    #expect(strip.segments.isEmpty)
  }

  // MARK: What's on it

  @Test func otherBlocksAreOnItWithTheirOwnState() {
    var s = withStudy()
    arrive(&s, libraryPlace, date(2026, 11, 17, 8))
    run(&s, date(2026, 11, 17, 10))
    let strip = day(s, date(2026, 11, 17, 10))
    #expect(strip.segments.map(\.kind) == [.study, .sleep])
    let study = strip.segments[0]
    #expect(study.state == .on)
    #expect(study.phase == .on)
    #expect(study.start == 2.0 / 24 && study.end == 10.0 / 24)
    #expect(study.title == "Study")
    #expect(plain(study.hours) == "9 am – 5 pm")
    #expect(study.apps == "3 apps")
    #expect(study.place == "Library")
    #expect(study.placeKind == .place)
    #expect(study.stateText == "On now")
    let night = strip.segments[1]
    #expect(night.title == "Your night")
    #expect(night.stateText == "Tonight")
    #expect(night.placeKind == .home)
    #expect(night.place == "Home")
    #expect(plain(night.spoken) == "Your night, 10:30 pm – 7:00 am, 4 apps, Home, Tonight")
  }

  @Test func laterEndedAndTomorrowSayWhen() {
    var s = withStudy()
    s.blocks.append(
      Block(
        id: BlockID("gym"), name: "Gym", kind: .gym, place: nil,
        schedule: .everyDay(TimeWindow(start: time(18), end: time(19))), apps: nil, appCount: 2))
    s.blocks.append(
      Block(
        id: BlockID("early"), name: "Early", kind: .other, place: nil,
        schedule: .everyDay(TimeWindow(start: time(5), end: time(6))), apps: nil, appCount: 1))
    let strip = day(s, date(2026, 11, 17, 17, 30))
    let text = Dictionary(uniqueKeysWithValues: strip.segments.map { ($0.block.raw, $0.stateText) })
    #expect(text["study"] == "Ended")
    #expect(text["gym"] == "Later today")
    #expect(text["early"] == "Tomorrow")
    #expect(strip.segments.first { $0.block.raw == "study" }?.phase == .ended)
    #expect(strip.segments.first { $0.block.raw == "gym" }?.placeKind == .anywhere)
  }

  @Test func aBlockSwitchedOffIsntOnIt() {
    var s = withStudy()
    s.blocks[1].isOn = false
    #expect(day(s, date(2026, 11, 17, 10)).segments.map(\.kind) == [.sleep])
  }

  @Test func awayInTheNightSaysWhenItLocks() {
    let strip = day(setUp(home: false), date(2026, 11, 17, 23))
    #expect(strip.segments.first?.state == .away)
    #expect(strip.segments.first?.phase == .later)
    #expect(strip.segments.first?.stateText == "Apps lock when you're home")
  }

  @Test func nothingWillBlockIsOff() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 23))
    let strip = day(s, date(2026, 11, 17, 23), blocking: false)
    #expect(strip.segments.map(\.state) == [.off])
    #expect(strip.segments.first?.stateText == "Off")
  }

  /// A pause open: the hero says until when, then that the night goes on; the strip says paused.
  @Test func anOpenPauseIsSaid() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 23))
    var door = Door(waitEndsAt: date(2026, 11, 17, 23, 1))
    door.openedAt = date(2026, 11, 17, 23, 1)
    door.expiresAt = date(2026, 11, 17, 23, 11)
    s.door = door
    let home = HomeSnapshot(state: s, log: [], now: date(2026, 11, 17, 23, 5), calendar: london)
    #expect(
      home.hero == .paused(until: date(2026, 11, 17, 23, 11), nightEnd: date(2026, 11, 18, 7)))
    #expect(home.eyebrow == "Paused until")
    #expect(home.timeline?.segments.first?.stateText == "Paused")
  }

  // MARK: Where a tap lands

  func strip(_ spans: [(Double, Double)]) -> DayTimeline {
    var strip = day(setUp(), date(2026, 11, 17, 19))
    let night = strip.segments[0]
    strip.segments = spans.map {
      var segment = night
      segment.start = $0.0
      segment.end = $0.1
      return segment
    }
    return strip
  }

  @Test func aShortSegmentIsWidenedToATapAndHeldInside() {
    let targets = strip([(0.5, 0.52), (0.98, 1)]).targets(minimum: 0.1)
    #expect(targets.count == 2)
    #expect(abs(targets[0].start - 0.46) < 1e-9 && abs(targets[0].end - 0.56) < 1e-9)
    #expect(abs(targets[1].start - 0.9) < 1e-9 && targets[1].end == 1)
  }

  @Test func neighboursSplitTheRoomWhenBothKeepATap() {
    let targets = strip([(0.2, 0.6), (0.62, 0.64)]).targets(minimum: 0.1)
    #expect(targets.map(\.segments) == [[0], [1]])
    #expect(abs(targets[0].end - 0.58) < 1e-9 && abs(targets[1].start - 0.58) < 1e-9)
    #expect(targets.allSatisfy { $0.end - $0.start >= 0.1 - 1e-9 })
  }

  @Test func twoTooCloseBecomeOneTargetShowingBoth() {
    let targets = strip([(0.4, 0.42), (0.45, 0.47), (0.8, 1)]).targets(minimum: 0.1)
    #expect(targets.map(\.segments) == [[0, 1], [2]])
    #expect(abs(targets[0].start - 0.36) < 1e-9 && abs(targets[0].end - 0.51) < 1e-9)
  }

  @Test func overlappingHoursAreOneTarget() {
    let targets = strip([(0.5, 0.7), (0.6, 0.9)]).targets(minimum: 0.1)
    #expect(targets.map(\.segments) == [[0, 1]])
  }

  @Test func theWordsArePlain() {
    let lines = [
      Copy.Strip.yourNight, Copy.Strip.onNow, Copy.Strip.paused, Copy.Strip.tonight,
      Copy.Strip.laterToday, Copy.Strip.tomorrow, Copy.Strip.ended, Copy.Strip.whenHome,
      Copy.Strip.whenThere, Copy.Strip.edit, Copy.Strip.hint, Copy.Home.locksAt,
      Copy.Home.blockedUntil, Copy.Home.pausedUntil, Copy.Home.nightEndsAt, Copy.Home.isOff,
      Copy.Morning.locked(from: "10:15 pm", to: "7:00 am"), Copy.Morning.lastNight,
      Copy.Home.nightsLabel(4), Copy.Insights.hoursLabel,
    ]
    for line in lines {
      #expect(!line.lowercased().contains("phone-free"), "\(line)")
      #expect(!line.lowercased().contains("block"), "the night isn't a block (D68): \(line)")
    }
  }
}
