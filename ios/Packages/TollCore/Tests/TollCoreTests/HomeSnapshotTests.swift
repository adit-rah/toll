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
    #expect(home.unlocksLeft == nil)
    #expect(home.timeline?.start == 4.5 / 16)
    #expect(home.timeline?.end == 13.0 / 16)
  }

  @Test func blockedShowsUntilAndUnlocks() {
    var s = setUp()
    run(&s, date(2026, 11, 17, 23))
    let home = snapshot(s, date(2026, 11, 17, 23))
    #expect(
      home.hero
        == .blocked(
          label: "Blocked until", until: date(2026, 11, 18, 7),
          detail: "You're home · 3 unlocks left"))
    #expect(home.timeline?.phase == .on)
    #expect(home.unlocksLeft == 3)
  }

  @Test func awayInsideTheNight() {
    let home = snapshot(setUp(home: false), date(2026, 11, 17, 23))
    #expect(home.hero == .away(start: date(2026, 11, 17, 22, 30)))
    #expect(home.pill == .init(text: "Away from home", kind: .away))
  }

  @Test func pausedAfterTheTrial() {
    var s = setUp()
    s.trial.start = date(2026, 11, 1, 12)
    run(&s, date(2026, 11, 17, 15))
    let home = snapshot(s, date(2026, 11, 17, 15))
    #expect(home.hero == .paused(endedToday: false))
    #expect(home.timeline?.phase == .paused)
    #expect(home.blocks.first?.trailing == Copy.Home.paused)
  }

  @Test func thePillIsQuietAndGoneAtNight() {
    var s = setUp()
    s.trial.start = date(2026, 11, 13, 15)
    #expect(
      snapshot(s, date(2026, 11, 17, 15)).pill
        == .init(text: "Night 5 of 7 free", kind: .trial))
    run(&s, date(2026, 11, 17, 23))
    #expect(snapshot(s, date(2026, 11, 17, 23)).pill == nil)
    var last = setUp()
    last.trial.start = date(2026, 11, 11, 15)
    #expect(snapshot(last, date(2026, 11, 17, 15)).pill?.opensPurchase == true)
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
    #expect(home.bars[2].isToday)
    #expect(home.bars.suffix(4).allSatisfy { $0.night == .ahead })
    #expect(!home.showsTrends)
    #expect(home.stopsChange == nil)
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
        .stopped(0), .stopped(1), .stopped(0), .noBlock, .stopped(0), .stopped(0), .stopped(0),
      ])
    #expect(home.nightsBlocked == 6)
    #expect(home.nightsCounted == 7)
    #expect(home.stopsChange == -3)
  }

  @Test func withoutLocationTheHeroSaysWhereverYouAre() {
    var s = setUp()
    s.location = .scheduleOnly
    let home = snapshot(s, date(2026, 11, 17, 19, 18))
    #expect(
      home.hero
        == .tonight(
          start: date(2026, 11, 17, 22, 30), detail: "Starts at 10:30\u{202F}pm, wherever you are")
        || home.hero
          == .tonight(
            start: date(2026, 11, 17, 22, 30), detail: "Starts at 10:30 pm, wherever you are")
        || home.hero
          == .tonight(
            start: date(2026, 11, 17, 22, 30), detail: "Starts at 22:30, wherever you are")
    )
  }

  @Test func blockRows() {
    var s = setUp()
    s.places.append(libraryPlace)
    s.blocks.append(studyBlock())
    let rows = snapshot(s, date(2026, 11, 21, 12)).blocks
    #expect(rows[0].detail.hasPrefix("Home · 10:30"))
    #expect(rows[0].trailing == "Tonight")
    #expect(rows[1].detail.hasSuffix("Weekdays"))
    #expect(rows[1].trailing == "Mon")
    // Thursday evening: Study is tomorrow, not tonight.
    let thursday = snapshot(s, date(2026, 11, 19, 18)).blocks
    #expect(thursday[0].trailing == "Tonight")
    #expect(thursday[1].trailing == "Fri")
    #expect(snapshot(s, date(2026, 11, 20, 7)).blocks[1].trailing == "Today")
  }

  @Test func theBannerOnlyWithoutLocation() {
    var s = setUp()
    s.setupFinishedAt = date(2026, 11, 15, 12)
    #expect(!snapshot(s, date(2026, 11, 17, 15)).locationBanner)
    s.location = .scheduleOnly
    #expect(snapshot(s, date(2026, 11, 17, 15)).locationBanner)
  }
}

struct LastNightTests {
  func line(_ at: Date, on: Bool, changed: Bool = true) -> Transition {
    Transition(
      at: at, cause: .windowStart, blockOn: on, changed: changed, home: true, inWindow: true,
      entitled: true)
  }

  @Test func theLatestStretch() {
    let log = [
      line(date(2026, 11, 16, 22, 31), on: true), line(date(2026, 11, 17, 7), on: false),
      line(date(2026, 11, 17, 22, 31), on: true),
      line(date(2026, 11, 17, 23), on: true, changed: false),
      line(date(2026, 11, 18, 7), on: false),
    ]
    #expect(
      LastNight(log: log) == LastNight(on: date(2026, 11, 17, 22, 31), off: date(2026, 11, 18, 7)))
    #expect(LastNight(log: []) == nil)
  }
}

extension LastNight {
  init(on: Date, off: Date?) {
    self.init(
      log: [
        Transition(
          at: on, cause: .windowStart, blockOn: true, changed: true, home: nil, inWindow: true,
          entitled: true)
      ]
        + (off.map {
          [
            Transition(
              at: $0, cause: .windowEnd, blockOn: false, changed: true, home: nil, inWindow: false,
              entitled: true)
          ]
        } ?? []))!
  }
}
