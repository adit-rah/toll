import Foundation
import SleepModel
import Testing

@testable import TollCore

/// D76 on screen: Tonight's lock and its gap, the strip's gap before the moon, Monday's card, the
/// offer to an install from before it, Settings › Before bed, the heads-up before the lock, and the
/// night record's gap and bed.
struct GapScreensTests {
  func plain(_ text: String?) -> String? { text?.replacingOccurrences(of: "\u{202F}", with: " ") }

  /// Set up on Monday the 16th at 3 pm, home set and at home, bought: a new install, gap 15.
  func installed() -> DuskState {
    var state = setUp()
    #expect(
      apply(
        .finishSetup(sleep: sleepBlock(), home: homePlace, trialStart: date(2026, 11, 16, 15)),
        &state, date(2026, 11, 16, 15)) == nil)
    state.trial.purchased = true
    state.dismissedCards = [TonightCard.headsUp.rawValue]
    run(&state, date(2026, 11, 16, 15))
    return state
  }

  func snapshot(_ state: DuskState, _ now: Date) -> HomeSnapshot {
    HomeSnapshot(state: state, log: [], now: now, calendar: london)
  }

  /// A week judged smooth: the gap grows from 15 to 30 at Monday noon.
  func grown() -> DuskState {
    var state = installed()
    for day in 16...20 {
      run(&state, date(2026, 11, day, 22, 20), .windowStart)
      run(&state, date(2026, 11, day + 1, 7, 1), .windowEnd)
    }
    run(&state, date(2026, 11, 23, 12))
    return state
  }

  // MARK: Tonight

  @Test func tonightSaysWhenAppsLockAndHowLongBeforeBed() {
    let home = snapshot(installed(), date(2026, 11, 17, 19))
    #expect(home.eyebrow == "Apps lock at")
    #expect(home.hero == .tonight(start: date(2026, 11, 17, 22, 15), detail: home.heroDetail))
    #expect(home.beforeBed == "15 min before bed")
  }

  @Test func noGapNoLine() {
    var state = installed()
    #expect(apply(.gap(.fixed(0)), &state, date(2026, 11, 17, 12)) == nil)
    let home = snapshot(state, date(2026, 11, 17, 19))
    #expect(home.beforeBed == nil)
    #expect(home.hero == .tonight(start: date(2026, 11, 17, 22, 30), detail: home.heroDetail))
  }

  @Test func theStripDrawsTheGapBeforeTheMoon() throws {
    let strip = DayTimeline(state: installed(), now: date(2026, 11, 17, 19), calendar: london)
    let night = try #require(strip.segments.first { $0.isNight })
    #expect(night.start == 15.25 / 24)
    #expect(night.bed == 15.5 / 24)
    #expect(night.end == 1)
    #expect(plain(night.hours) == "10:15 pm – 7:00 am")
    #expect(plain(night.bedText) == "Bed at 10:30 pm")
    #expect(plain(night.spoken)?.contains("10:15 pm – 7:00 am, Bed at 10:30 pm") == true)
  }

  // MARK: Monday's card

  @Test func mondaysCardSaysThisWeeksGapAndOffersLastWeeks() throws {
    let state = grown()
    let home = snapshot(state, date(2026, 11, 23, 14))
    #expect(home.card == .gapWeek)
    let card = try #require(home.gapCard)
    #expect(card.title == "This week, apps lock 30 min before bed")
    #expect(card.detail == "Up from 15")
    #expect(card.action == "Keep 15")
    #expect(card.dismiss == "OK")
    // Quiet while the night is on, and gone after Tuesday noon.
    #expect(snapshot(state, date(2026, 11, 24, 11)).card == .gapWeek)
    #expect(snapshot(state, date(2026, 11, 24, 12)).card == nil)
  }

  @Test func anEaseShowsOnlyTheNewNumber() throws {
    var state = installed()
    state.gap.minutes = 30
    state.gap.tally.pausesInGap = 2
    run(&state, date(2026, 11, 23, 12))
    let card = try #require(snapshot(state, date(2026, 11, 23, 14)).gapCard)
    #expect(card.title == "This week, apps lock 15 min before bed")
    #expect(card.detail == nil && card.action == nil)
  }

  @Test func mondaysCardGoesOnceAnswered() {
    var kept = grown()
    #expect(apply(.keepGap, &kept, date(2026, 11, 23, 14)) == nil)
    #expect(snapshot(kept, date(2026, 11, 23, 14)).card == nil)
    var put = grown()
    #expect(apply(.dismissCard(.gapWeek), &put, date(2026, 11, 23, 14)) == nil)
    #expect(snapshot(put, date(2026, 11, 23, 14)).card == nil)
    #expect(put.gap.minutes == 30)
    #expect(!put.dismissed(.gapWeek))
  }

  // MARK: Installs from before D76

  @Test func anInstallFromBeforeKeepsItsNightAndIsOfferedTheGapOnce() throws {
    var old = setUp()
    old.setupFinishedAt = date(2026, 11, 10, 15)
    old.trial.start = date(2026, 11, 10, 15)
    old.trial.purchased = true
    old.dismissedCards = [TonightCard.home.rawValue, TonightCard.headsUp.rawValue]
    let encoded = try DuskStore.encoder.encode(old)
    let object = try JSONSerialization.jsonObject(with: encoded)
    var json = try #require(object as? [String: Any])
    json["gap"] = nil
    let state = DuskStore.decode(try JSONSerialization.data(withJSONObject: json))
    #expect(state.gap.minutes == 0)
    #expect(state.gap.offered)
    let home = snapshot(state, date(2026, 11, 17, 15))
    #expect(home.hero == .tonight(start: date(2026, 11, 17, 22, 30), detail: home.heroDetail))
    #expect(home.card == .gapOffer)
    let card = try #require(home.gapCard)
    #expect(card.title == "Lock apps 15 min before bed?")
    #expect(plain(card.detail) == "Apps lock at 10:15 pm. Your night still ends at 7:00 am.")
    #expect(card.action == "Turn on")

    var yes = state
    #expect(apply(.gap(.grows(15)), &yes, date(2026, 11, 17, 15)) == nil)
    #expect(yes.gap.minutes == 15 && yes.gap.mode == .grows && !yes.gap.offered)
    #expect(snapshot(yes, date(2026, 11, 17, 15)).card == nil)
    // Nights before it was turned on had no gap.
    #expect(yes.gap.minutes(forNight: date(2026, 11, 16, 0)) == 0)
    #expect(yes.gap.minutes(forNight: date(2026, 11, 17, 0)) == 15)

    var no = state
    #expect(apply(.dismissCard(.gapOffer), &no, date(2026, 11, 17, 15)) == nil)
    #expect(no.gap.minutes == 0)
    #expect(snapshot(no, date(2026, 11, 17, 15)).card == nil)
  }

  @Test func stepTwosFileIsAnInstallFromBefore() {
    #expect(Migration.fromV1(LegacyStateV1(settings: .init(window: usual))).gap == .existing)
  }

  // MARK: Settings › Before bed

  @Test func beforeBedSaysNowAndNext() {
    var state = installed()
    #expect(BeforeBed(state: state).detail == "Grows with you · now 15 min · next 30")
    state.gap.minutes = 60
    #expect(BeforeBed(state: state).detail == "Grows with you · now 60 min")
    #expect(apply(.gap(.fixed(45)), &state, date(2026, 11, 17, 12)) == nil)
    #expect(BeforeBed(state: state).detail == "Fixed · 45 min")
    #expect(apply(.gap(.fixed(0)), &state, date(2026, 11, 17, 12)) == nil)
    #expect(BeforeBed(state: state).detail == "None · apps lock at bed")
    #expect(BeforeBed.choices() == [0, 15, 30, 45, 60, 75, 90])
  }

  @Test func aChangeHeldThroughTonightSaysSo() {
    var state = installed()
    run(&state, date(2026, 11, 16, 23))
    #expect(apply(.gap(.fixed(30)), &state, date(2026, 11, 16, 23)) == nil)
    let row = BeforeBed(state: state)
    #expect(row.setting == .fixed(30))
    #expect(row.held)
    #expect(row.detail == "Fixed · 30 min · From tomorrow night")
  }

  // MARK: The heads-up and Ready

  @Test func theHeadsUpComesTwentyMinutesBeforeTheLock() {
    var state = installed()
    var ups = HeadsUp.schedule(
      state, screenTime: true, permission: .allowed, now: date(2026, 11, 17, 15), calendar: london)
    #expect(ups.first?.at == date(2026, 11, 17, 21, 55))
    #expect(plain(ups.first?.body) == "10:15 pm – 7:00 am")
    // A change held through tonight moves every heads-up after it.
    run(&state, date(2026, 11, 17, 23))
    #expect(apply(.gap(.fixed(60)), &state, date(2026, 11, 17, 23)) == nil)
    ups = HeadsUp.schedule(
      state, screenTime: true, permission: .allowed, now: date(2026, 11, 17, 23), calendar: london)
    #expect(ups.first?.at == date(2026, 11, 18, 21, 10))
  }

  @Test func readysPictureShowsTheLockBeforeBed() throws {
    let picture = try #require(
      NightPicture(.everyDay(usual), gap: 15, now: date(2026, 11, 17, 15), calendar: london))
    #expect(plain(picture.start) == "10:30 pm")
    #expect(picture.timeline.lock == 4.25 / 16)
    #expect(picture.timeline.start == 4.5 / 16)
    #expect(plain(picture.timeline.label) == "Night, 10:30 pm to 7:00 am, apps lock at 10:15 pm")
    #expect(
      NightPicture(.everyDay(usual), now: date(2026, 11, 17, 15), calendar: london)?
        .timeline.lock == nil)
  }

  // MARK: The night record

  @Test func theRecordCarriesTheGapAndBed() throws {
    let state = grown()
    let log = [
      Transition(
        at: date(2026, 11, 23, 22), cause: .windowStart, blockOn: true, changed: true, home: true,
        inWindow: true, entitled: true, active: [BlockID("sleep")]),
      Transition(
        at: date(2026, 11, 24, 7), cause: .windowEnd, blockOn: false, changed: true, home: true,
        inWindow: false, entitled: true, active: []),
    ]
    let nights = NightFacts.ended(
      log: log, sleep: sleepBlock(), gap: state.gap, since: date(2026, 11, 16, 15),
      now: date(2026, 11, 24, 9), calendar: london)
    // Last week's nights had 15; Monday's had 30.
    #expect(nights.first?.gap == 15)
    let monday = try #require(nights.last)
    #expect(monday.gap == 30)
    #expect(monday.bed == date(2026, 11, 23, 22, 30))
    #expect(monday.plannedStart == date(2026, 11, 23, 22))
    let data = try #require(NightRecordLine.encode(monday, calendar: london))
    let record = try JSONDecoder().decode(NightRecord.self, from: data)
    #expect(record.plannedBedtime.hasPrefix("2026-11-23T22:30:00"))
    #expect(record.bed == record.plannedBedtime)
    #expect(record.gapMin == 30)
  }
}

extension HomeSnapshot {
  /// The hero's line, whatever it says, so a test can compare the time alone.
  var heroDetail: String {
    if case .tonight(_, let detail) = hero { return detail }
    return ""
  }
}
