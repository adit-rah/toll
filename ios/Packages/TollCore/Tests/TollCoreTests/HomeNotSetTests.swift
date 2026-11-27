import Foundation
import Testing

@testable import TollCore

/// D68: onboarding sets no home. The night runs on its hours anywhere until home is set from Tonight's
/// card or Settings; then it's the usual home × night × entitled (B-1).
struct HomeNotSetTests {
  let sleepID = BlockID("sleep")

  /// Set up as onboarding leaves it: the Sleep block with no place, location never asked.
  func fresh(finished: Date = date(2026, 11, 16, 21)) -> DuskState {
    var state = DuskState()
    state.blocks = [sleepBlock(place: nil)]
    state.setupFinishedAt = finished
    state.trial.start = finished
    return state
  }

  /// iOS's formatter puts a narrow space before am and pm.
  func plain(_ text: String?) -> String? { text?.replacingOccurrences(of: "\u{202F}", with: " ") }

  func snapshot(_ state: DuskState, _ now: Date, screenTime: Bool = true) -> HomeSnapshot {
    HomeSnapshot(state: state, log: [], now: now, calendar: london, screenTime: screenTime)
  }

  // MARK: The engine

  @Test(arguments: [LocationMode.places, .scheduleOnly])
  func theNightRunsOnItsHoursWhereverThePhoneIs(location: LocationMode) {
    var s = fresh()
    s.location = location
    run(&s, date(2026, 11, 17, 22, 30), .windowStart)
    #expect(s.runtime.active[sleepID] == date(2026, 11, 18, 7))
    run(&s, date(2026, 11, 18, 7), .windowEnd)
    #expect(!s.isBlocking)
  }

  @Test func settingHomeMakesTheNightWaitForIt() {
    var s = fresh()
    #expect(!s.homeIsSet)
    #expect(apply(.setHome(homePlace), &s, date(2026, 11, 17, 15)) == nil)
    #expect(s.homeIsSet)
    #expect(s.sleepBlock?.place == homePlace.id)
    #expect(s.places == [homePlace])
    run(&s, date(2026, 11, 17, 22, 30), .windowStart)
    #expect(!s.isBlocking)
    arrive(&s, homePlace, date(2026, 11, 17, 23))
    let effects = run(&s, date(2026, 11, 17, 23), .arrived)
    #expect(s.isBlocking)
    #expect(effects.places == [homePlace])
  }

  @Test func settingHomeDuringTheNightWaitsUntilItEnds() {
    var s = fresh()
    run(&s, date(2026, 11, 17, 23))
    #expect(apply(.setHome(homePlace), &s, date(2026, 11, 17, 23, 30)) == nil)
    #expect(s.sleepBlock?.place == nil)
    #expect(s.homeIsSet)
    // Away from the new home, tonight still runs as it started (B-3).
    run(&s, date(2026, 11, 18, 2))
    #expect(s.isBlocking)
    run(&s, date(2026, 11, 18, 7, 5))
    #expect(s.sleepBlock?.place == homePlace.id)
    #expect(s.pending.isEmpty)
  }

  @Test func settingHomeKeepsAnEditThatWasWaiting() {
    var s = fresh()
    run(&s, date(2026, 11, 17, 23))
    var later = sleepBlock(TimeWindow(start: time(23), end: time(7)), place: nil)
    later.appCount = 4
    #expect(apply(.saveBlock(later), &s, date(2026, 11, 17, 23, 10)) == nil)
    #expect(apply(.setHome(homePlace), &s, date(2026, 11, 17, 23, 30)) == nil)
    guard case .save(let held) = s.pending[sleepID] else {
      Issue.record("no held edit")
      return
    }
    #expect(held.schedule == .everyDay(TimeWindow(start: time(23), end: time(7))))
    #expect(held.place == homePlace.id)
  }

  @Test func movingASetHomeKeepsOnePlace() {
    var s = setUp()
    s.setupFinishedAt = date(2026, 11, 10, 20)
    var moved = homePlace
    moved.latitude = 51.6
    #expect(apply(.setHome(moved), &s, date(2026, 11, 17, 15)) == nil)
    #expect(s.places == [moved])
    #expect(s.sleepBlock?.place == homePlace.id)
  }

  /// The way back to anywhere (the audit): home stays saved, the night stops waiting for it, and
  /// during the night the change waits for its end, which Settings shows.
  @Test func useAnywhereUndoesHome() {
    var s = setUp()
    s.setupFinishedAt = date(2026, 11, 10, 20)
    #expect(apply(.useAnywhere, &s, date(2026, 11, 17, 15)) == nil)
    #expect(!s.homeIsSet && s.sleepBlock?.place == nil)
    #expect(s.places == [homePlace])
    #expect(s.homeChangeAt == nil)

    var night = setUp()
    night.setupFinishedAt = date(2026, 11, 10, 20)
    run(&night, date(2026, 11, 17, 23))
    #expect(apply(.useAnywhere, &night, date(2026, 11, 17, 23, 30)) == nil)
    #expect(!night.homeIsSet)
    #expect(night.sleepBlock?.place == homePlace.id)
    #expect(night.homeChangeAt == date(2026, 11, 18, 7))
    // Tonight's hero says it too, beside what's true tonight (#129).
    if case .blocked(_, let detail) = snapshot(night, date(2026, 11, 17, 23, 30)).hero {
      #expect(detail == "You're home · Anywhere from the next night")
    } else {
      Issue.record("not blocked")
    }
    run(&night, date(2026, 11, 18, 7, 5))
    #expect(night.sleepBlock?.place == nil && night.homeChangeAt == nil)
  }

  /// Settings' last night is the night's own, with its day, not the latest of any block.
  @Test func lastNightIsTheNights() throws {
    var s = setUp()
    s.setupFinishedAt = date(2026, 11, 10, 20)
    s.blocks.append(studyBlock())
    func line(_ at: Date, _ active: [BlockID]) -> Transition {
      Transition(
        at: at, cause: .windowStart, blockOn: !active.isEmpty, changed: true, home: true,
        inWindow: true, entitled: true, active: active)
    }
    let log = [
      line(date(2026, 11, 16, 22, 30), [sleepID]), line(date(2026, 11, 17, 7), []),
      line(date(2026, 11, 17, 9), [BlockID("study")]), line(date(2026, 11, 17, 17), []),
    ]
    let last = try #require(
      PastNight.latest(
        history: [], state: s, log: log, now: date(2026, 11, 17, 18), calendar: london))
    #expect(last.night == date(2026, 11, 16, 0))
    #expect(last.start == date(2026, 11, 16, 22, 30) && last.end == date(2026, 11, 17, 7))
  }

  @Test func settingHomeNeedsTheSleepBlock() {
    var s = DuskState()
    #expect(apply(.setHome(homePlace), &s, date(2026, 11, 17, 15)) == .noSleepBlock)
    #expect(s.places.isEmpty)
  }

  // MARK: Tonight

  @Test func tonightSaysAnywherePlainly() {
    let home = snapshot(fresh(), date(2026, 11, 17, 19, 18))
    #expect(
      home.hero
        == .tonight(start: date(2026, 11, 17, 22, 30), detail: "Anywhere · starts in 3 h 12 m"))
    #expect(home.heroPlace == .anywhere)
    #expect(!home.locationBanner)
  }

  /// Tonight doesn't mention other blocks (D68): a day block at a place without Always says so on
  /// Blocks ("Anywhere"), not with Tonight's card.
  @Test func withoutAlwaysOnlyANightAtHomeGetsTheLocationCard() {
    var s = fresh()
    s.location = .scheduleOnly
    #expect(!snapshot(s, date(2026, 11, 17, 15)).locationBanner)
    s.places = [libraryPlace]
    s.blocks.append(studyBlock())
    #expect(!snapshot(s, date(2026, 11, 17, 15)).locationBanner)
    #expect(
      BlocksSnapshot(state: s, now: date(2026, 11, 17, 15), calendar: london).others[0].detail
        .hasPrefix("Anywhere"))
    s.places.append(homePlace)
    s.blocks[0].place = homePlace.id
    #expect(snapshot(s, date(2026, 11, 17, 15)).locationBanner)
    #expect(snapshot(s, date(2026, 11, 17, 15)).card == nil)
  }

  @Test func theHomeCardComesTheMorningAfterTheFirstNight() {
    let s = fresh()
    #expect(snapshot(s, date(2026, 11, 16, 21, 30)).card == nil)
    #expect(snapshot(s, date(2026, 11, 17, 6, 59)).card == nil)
    #expect(snapshot(s, date(2026, 11, 17, 7, 30)).card == .home)
    #expect(snapshot(s, date(2026, 11, 20, 15)).card == .home)
  }

  @Test func setupDuringANightCountsThatNight() {
    let s = fresh(finished: date(2026, 11, 17, 2))
    #expect(snapshot(s, date(2026, 11, 17, 6)).card == nil)
    #expect(snapshot(s, date(2026, 11, 17, 8)).card == .home)
  }

  @Test func dismissingTheCardPutsItAwayForGood() {
    var s = fresh()
    #expect(apply(.dismissCard(.home), &s, date(2026, 11, 17, 8)) == nil)
    #expect(s.dismissed(.home))
    #expect(snapshot(s, date(2026, 11, 17, 8)).card == nil)
    #expect(snapshot(s, date(2026, 11, 24, 8)).card == nil)
  }

  @Test func theCardGoesOnceHomeIsSetEvenWhileTheEditWaits() {
    var s = fresh()
    #expect(apply(.setHome(homePlace), &s, date(2026, 11, 17, 8)) == nil)
    #expect(snapshot(s, date(2026, 11, 17, 8)).card == nil)
    // An existing user with home set never sees it.
    var existing = setUp()
    existing.setupFinishedAt = date(2026, 11, 10, 20)
    #expect(snapshot(existing, date(2026, 11, 17, 15)).card == nil)
  }

  @Test func theCardIsQuietAtNightAndGivesWayToAWarning() {
    var s = fresh()
    run(&s, date(2026, 11, 17, 23))
    #expect(snapshot(s, date(2026, 11, 17, 23)).card == nil)
    let day = fresh()
    let off = snapshot(day, date(2026, 11, 17, 15), screenTime: false)
    #expect(off.screenTimeOff)
    #expect(off.card == nil)
  }

  @Test func noCardOnceTheFreeWeekIsOver() {
    var s = fresh(finished: date(2026, 11, 1, 21))
    run(&s, date(2026, 11, 17, 15))
    #expect(!s.trial.entitled)
    #expect(snapshot(s, date(2026, 11, 17, 15)).card == nil)
  }

  // MARK: The state file

  @Test func filesFromBeforeTheCardStillLoad() throws {
    let state = fresh()
    var json = try #require(
      try JSONSerialization.jsonObject(with: DuskStore.encoder.encode(state)) as? [String: Any])
    json["dismissedCards"] = nil
    let loaded = DuskStore.decode(try JSONSerialization.data(withJSONObject: json))
    #expect(loaded.dismissedCards.isEmpty)
    #expect(loaded.blocks == state.blocks)
  }

  @Test func aCardKindFromALaterBuildDoesNotStopTheFileLoading() throws {
    var state = fresh()
    state.dismissedCards = ["someLaterCard"]
    let loaded = DuskStore.decode(try DuskStore.encoder.encode(state))
    #expect(loaded.dismissedCards == ["someLaterCard"])
    #expect(!loaded.dismissed(.home))
    #expect(loaded.blocks.count == 1)
  }

  // MARK: Setup's picture of the night

  @Test func theNightIsDrawnOnItsOwnStrip() {
    let picture = NightPicture(.everyDay(usual), now: date(2026, 11, 17, 15), calendar: london)
    #expect(plain(picture?.start) == "10:30 pm")
    #expect(plain(picture?.end) == "7:00 am")
    #expect(picture?.length == "8 h 30 m")
    #expect(picture?.timeline.start == 4.5 / 16)
    #expect(picture?.timeline.end == 13.0 / 16)
    #expect(
      picture?.timeline.hours.map { plain($0) } == ["6 pm", "10 pm", "2 am", "6 am", "10 am"])
    #expect(plain(picture?.timeline.label) == "Night, 10:30 pm to 7:00 am")
  }

  @Test func turningTheWheelMovesTheNightNotTheStrip() {
    let early = NightPicture(
      .everyDay(TimeWindow(wake: time(6), leadHours: 8.5)), now: date(2026, 11, 17, 15),
      calendar: london)
    let late = NightPicture(
      .everyDay(TimeWindow(wake: time(8), leadHours: 8.5)), now: date(2026, 11, 17, 15),
      calendar: london)
    #expect(early?.timeline.hours == late?.timeline.hours)
    #expect((early?.timeline.start ?? 1) < (late?.timeline.start ?? 0))
  }

  @Test func aNightOffTheBoardsGetsAStripThatFitsIt() {
    let day = TimeWindow(start: time(13, 19), end: time(7, 49))
    let picture = NightPicture(.everyDay(day), now: date(2026, 11, 17, 9), calendar: london)
    #expect(picture?.timeline.start ?? -1 > 0)
    #expect(picture?.timeline.end ?? 2 < 1)
    #expect(plain(picture?.start) == "1:19 pm")
  }
}
