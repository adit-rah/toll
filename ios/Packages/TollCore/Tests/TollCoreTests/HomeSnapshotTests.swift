import Foundation
import Testing

@testable import TollCore

struct HomeSnapshotTests {
  func snapshot(_ state: DuskState, _ now: Date, log: [Transition] = []) -> HomeSnapshot {
    HomeSnapshot(state: state, log: log, now: now, calendar: london)
  }

  func line(_ at: Date, _ cause: ReconcileCause, on: Bool = true, changed: Bool = false)
    -> Transition
  {
    Transition(
      at: at, cause: cause, blockOn: on, changed: changed, home: true, inWindow: true,
      entitled: true)
  }

  @Test func eveningAtHomeSaysWhenItStarts() {
    var s = setUp()
    s.setupFinishedAt = date(2026, 11, 13, 20)
    let home = snapshot(s, date(2026, 11, 17, 19, 18))
    #expect(
      home.hero
        == .tonight(start: date(2026, 11, 17, 22, 30), detail: "At home · starts in 3 h 12 m"))
    #expect(home.eyebrow == "Apps lock at")
    #expect(home.unlocksLeft == nil)
    #expect(home.timeline?.segments.map(\.state) == [.later])
  }

  @Test func blockedShowsUntilAndUnlocks() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 23))
    let home = snapshot(s, date(2026, 11, 17, 23))
    #expect(
      home.hero
        == .blocked(until: date(2026, 11, 18, 7), detail: "You're home"))
    #expect(home.eyebrow == "Apps locked until")
    #expect(home.timeline?.segments.map(\.state) == [.on])
    #expect(home.unlocksLeft == 3)
  }

  @Test func awayInsideTheNight() {
    let home = snapshot(setUp(home: false), date(2026, 11, 17, 23))
    #expect(home.hero == .away(end: date(2026, 11, 18, 7)))
    #expect(home.eyebrow == "Night ends at")
    // The hero says away; the pill neither repeats it nor sells at night (D33).
    #expect(home.pill == nil)
    #expect(home.timeline?.label == nil)
    #expect(home.timeline?.segments.first?.stateText == "Apps lock when you're home")
  }

  /// With no night, the way forward is its editor, and there's nothing to sell yet (the audit).
  @Test func noNightOffersToSetIt() {
    var s = setUp()
    s.trial.start = date(2026, 11, 13, 15)
    if let index = s.blocks.firstIndex(where: \.isSleep) {
      s.blocks[index].schedule = WeeklySchedule(rules: [])
    }
    let home = snapshot(s, date(2026, 11, 17, 15))
    #expect(home.hero == .noBlocks)
    #expect(home.eyebrow == "Your night")
    #expect(home.setNight == s.sleepBlock?.id)
    #expect(home.pill == nil)
    #expect(snapshot(setUp(), date(2026, 11, 17, 15)).setNight == nil)
  }

  @Test func offAfterTheTrial() {
    var s = setUp()
    s.trial.start = date(2026, 11, 1, 12)
    run(&s, date(2026, 11, 17, 15))
    let home = snapshot(s, date(2026, 11, 17, 15))
    #expect(home.hero == .off(endedToday: false))
    #expect(home.eyebrow == "Dusk is off")
    #expect(
      YourSleep(state: s, log: [], history: [], now: date(2026, 11, 17, 15), calendar: london)
        .weekTitle == "Your free nights")
    #expect(home.timeline?.segments.map(\.phase) == [.off])
    #expect(
      BlocksSnapshot(state: s, now: date(2026, 11, 17, 15), calendar: london).night?.stateText
        == Copy.Home.off)
  }

  @Test func thePillIsQuietAndGoneAtNight() {
    var s = setUp()
    s.trial.start = date(2026, 11, 13, 15)
    #expect(
      snapshot(s, date(2026, 11, 17, 15)).pill
        == .init(text: "Night 5 of 14 free", kind: .trial, night: 5, nights: 14))
    run(&s, date(2026, 11, 17, 23))
    #expect(snapshot(s, date(2026, 11, 17, 23)).pill == nil)
    var last = setUp()
    last.trial.start = date(2026, 11, 4, 15)
    #expect(snapshot(last, date(2026, 11, 17, 15)).pill?.kind == .lastNight)
  }

  @Test func theFirstWeekShowsNightsSinceSetupThenWhatIsAhead() {
    var s = setUp()
    s.setupFinishedAt = date(2026, 11, 15, 12)
    let log = [
      line(date(2026, 11, 15, 22, 30), .windowStart, changed: true),
      line(date(2026, 11, 15, 23), .blockScreen),
      line(date(2026, 11, 16, 1), .blockScreen),
      line(date(2026, 11, 16, 22, 30), .windowStart, changed: true),
      line(date(2026, 11, 17, 2), .blockScreen),
    ]
    let home = snapshot(s, date(2026, 11, 17, 19), log: log)
    #expect(home.nightsCounted == 2)
    #expect(home.nightsBlocked == 2)
    #expect(home.timesStopped == 3)
    #expect(home.bars.count == 7)
    #expect(home.bars.prefix(3).map(\.night) == [.stopped(2), .stopped(1), .ahead])
    #expect(home.bars.map(\.isLatest) == [false, true, false, false, false, false, false])
    #expect(home.bars.suffix(4).allSatisfy { $0.night == .ahead })
  }

  @Test func laterTheLastSevenNightsWithDashesAndZeros() {
    var s = setUp()
    s.setupFinishedAt = date(2026, 11, 1, 12)
    var log: [Transition] = []
    for day in 10...16 where day != 13 {
      log.append(line(date(2026, 11, day, 22, 30), .windowStart, changed: true))
    }
    log.append(line(date(2026, 11, 11, 23), .blockScreen))
    log.append(line(date(2026, 11, 3, 23), .windowStart, changed: true))
    for _ in 0..<4 { log.append(line(date(2026, 11, 3, 23, 30), .blockScreen)) }
    log.sort { $0.at < $1.at }
    let home = snapshot(s, date(2026, 11, 16, 23), log: log)
    #expect(
      home.bars.map(\.night) == [
        .stopped(0), .stopped(1), .stopped(0), .missed, .stopped(0), .stopped(0), .stopped(0),
      ])
    #expect(home.nightsBlocked == 6)
    #expect(home.nightsCounted == 7)
    #expect(home.bars.last?.isLatest == true)
  }

  /// Nothing can block with Screen Time off, so Home doesn't say "Blocked until" (#45).
  @Test func screenTimeOffSaysNothingIsBlocked() {
    var s = setUp()
    s.setupFinishedAt = date(2026, 11, 13, 20)
    s.trial.start = date(2026, 11, 13, 20)
    run(&s, date(2026, 11, 17, 23))
    let home = HomeSnapshot(
      state: s, log: [], now: date(2026, 11, 17, 23), calendar: london, screenTime: false)
    #expect(home.screenTimeOff)
    #expect(home.hero == .screenTimeOff)
    #expect(home.eyebrow == "Screen Time is off")
    #expect(home.unlocksLeft == nil)
    #expect(home.timeline?.segments.map(\.phase) == [.off])
    #expect(
      BlocksSnapshot(
        state: s, now: date(2026, 11, 17, 23), calendar: london, screenTime: false
      ).night?.stateText == Copy.Home.off)
    #expect(!snapshot(s, date(2026, 11, 17, 23)).screenTimeOff)
  }

  @Test func withoutLocationTheHeroSaysWhereverYouAre() {
    var s = setUp()
    s.location = .scheduleOnly
    let home = snapshot(s, date(2026, 11, 17, 19, 18))
    // The start is the big time, so the line doesn't repeat it (D75).
    #expect(
      home.hero
        == .tonight(start: date(2026, 11, 17, 22, 30), detail: "Anywhere · starts in 3 h 12 m"))
  }

  @Test func theBannerOnlyWithoutLocation() {
    var s = setUp()
    s.setupFinishedAt = date(2026, 11, 15, 12)
    #expect(!snapshot(s, date(2026, 11, 17, 15)).locationBanner)
    s.location = .scheduleOnly
    #expect(snapshot(s, date(2026, 11, 17, 15)).locationBanner)
  }
}
