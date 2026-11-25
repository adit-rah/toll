import Foundation
import Testing

@testable import TollCore

/// Tonight's band (`TonightBand`): each kind in its part of the day, one card by kind, and last
/// night's row under it, nearest the strip. The night locks at 10 pm here.
struct TonightBandTests {
  typealias Facts = TonightBand.Facts
  let lock = date(2026, 11, 17, 22)

  /// A day after setup, with a night behind it and the lock at 10 pm.
  func facts(_ change: (inout Facts) -> Void = { _ in }) -> Facts {
    var facts = Facts()
    facts.nextLock = lock
    facts.nightEnded = true
    change(&facts)
    return facts
  }

  func band(_ facts: Facts, _ hour: Int, _ minute: Int = 0) -> [TonightBand.Item] {
    TonightBand(facts, now: date(2026, 11, 17, hour, minute), calendar: london).items
  }

  // MARK: Each kind's part of the day

  /// Problems show at any time, the night included, until they're fixed.
  @Test func aProblemShowsAllDayAndNight() {
    let problem = facts { $0.location = true }
    for hour in [8, 15, 21] { #expect(band(problem, hour) == [.location]) }
    var night = problem
    night.nightOn = true
    night.blocking = true
    night.beforeBed = true
    #expect(band(night, 22, 15) == [.location])
  }

  /// Last night's row runs from the night's end until noon, never in the hour before the lock or
  /// once the next night is on, and not after "OK".
  @Test func lastNightIsTheMorningsUntilNoon() {
    let morning = facts { $0.lastNight = true }
    #expect(band(morning, 7, 5) == [.lastNight])
    #expect(band(morning, 11, 59) == [.lastNight])
    #expect(band(morning, 12) == [])
    #expect(band(morning, 15) == [])
    var seen = morning
    seen.lastNightPutAway = true
    #expect(band(seen, 8) == [])
    // A night that locks before noon: the hour before it is the night's.
    var early = morning
    early.nextLock = date(2026, 11, 17, 11, 30)
    #expect(band(early, 10, 29) == [.lastNight])
    #expect(band(early, 10, 30) == [])
    var on = morning
    on.nightOn = true
    #expect(band(on, 9) == [])
  }

  /// Setup offers wait for a calm time: not in the hour before the lock, not while anything is
  /// locked, not before a night has ended since setup, not once the free nights are over.
  @Test func setupOffersOnlyAtCalmTimes() {
    let offer = facts { $0.setup = .home }
    #expect(band(offer, 8) == [.card(.home)])
    #expect(band(offer, 15) == [.card(.home)])
    #expect(band(offer, 20, 59) == [.card(.home)])
    #expect(band(offer, 21) == [])
    #expect(band(offer, 21, 45) == [])
    var locked = offer
    locked.blocking = true
    #expect(band(locked, 11) == [])
    var first = offer
    first.nightEnded = false
    #expect(band(first, 15) == [])
    var over = offer
    over.entitled = false
    #expect(band(over, 15) == [])
    var night = offer
    night.nightOn = true
    #expect(band(night, 23) == [])
  }

  /// A one-time flow (D92) keeps the same calm times as the offers, even on the first day.
  @Test func aFlowWaitsForACalmTime() {
    let flow = facts {
      $0.flow = "fit"
      $0.nightEnded = false
    }
    #expect(band(flow, 15) == [.flow("fit")])
    #expect(band(flow, 21, 30) == [])
    var locked = flow
    locked.blocking = true
    #expect(band(locked, 15) == [])
  }

  /// Before bed's card is the gap's alone; Monday's card is about tonight and may stay into the
  /// hour before the lock, but never while anything is locked.
  @Test func nightCardsBelongToTheNight() {
    let gap = facts {
      $0.beforeBed = true
      $0.nightOn = true
      $0.blocking = true
    }
    #expect(band(gap, 22, 15) == [.card(.beforeBed)])
    var offGap = gap
    offGap.nightOn = false
    #expect(band(offGap, 15) == [])
    let monday = facts { $0.gapWeek = true }
    #expect(band(monday, 15) == [.card(.gapWeek)])
    #expect(band(monday, 21, 30) == [.card(.gapWeek)])
    var locked = monday
    locked.blocking = true
    #expect(band(locked, 15) == [])
  }

  /// From an hour before the lock the band is the night's: the heads-up's 20 minutes and the
  /// flows' quiet minutes fall inside it.
  @Test func theNightsHourStartsAnHourBeforeTheLock() {
    #expect(TonightBand.nightOwns(facts(), now: date(2026, 11, 17, 20, 59)) == false)
    #expect(TonightBand.nightOwns(facts(), now: date(2026, 11, 17, 21)))
    #expect(TonightBand.nightOwns(facts { $0.nextLock = nil }, now: lock) == false)
    #expect(TonightBand.nightOwns(facts { $0.nightOn = true }, now: date(2026, 11, 17, 9)))
  }

  // MARK: Priorities

  /// One card: problems first (Screen Time, a build that can't save, a lost night's apps,
  /// location), then the night's, then a flow, then an offer.
  @Test func oneCardByKind() {
    var all = facts {
      $0.screenTimeOff = true
      $0.readOnly = true
      $0.recovered = true
      $0.location = true
      $0.gapWeek = true
      $0.flow = "fit"
      $0.setup = .home
    }
    #expect(band(all, 15) == [.screenTimeOff])
    all.screenTimeOff = false
    #expect(band(all, 15) == [.readOnly])
    all.readOnly = false
    #expect(band(all, 15) == [.recovered])
    all.recovered = false
    #expect(band(all, 15) == [.location])
    all.location = false
    #expect(band(all, 15) == [.card(.gapWeek)])
    all.gapWeek = false
    #expect(band(all, 15) == [.flow("fit")])
    all.flow = nil
    #expect(band(all, 15) == [.card(.home)])
    #expect(TonightBand.Kind.allCases.sorted() == [.problem, .night, .flow, .setup, .review])
  }

  // MARK: Pairs

  /// Every kind that can share the morning with last night: the card above, the row nearest the
  /// strip.
  @Test func lastNightsRowSitsUnderTheCard() {
    let cards: [(Facts, TonightBand.Item)] = [
      (facts { $0.location = true }, .location),
      (facts { $0.recovered = true }, .recovered),
      (facts { $0.readOnly = true }, .readOnly),
      (facts { $0.gapWeek = true }, .card(.gapWeek)),
      (facts { $0.flow = "fit" }, .flow("fit")),
      (facts { $0.setup = .home }, .card(.home)),
      (facts { $0.setup = .headsUp }, .card(.headsUp)),
      (facts { $0.setup = .gapOffer }, .card(.gapOffer)),
    ]
    for (card, item) in cards {
      var morning = card
      morning.lastNight = true
      #expect(band(morning, 8, 10) == [item, .lastNight])
    }
  }

  /// Pairs of cards never stack: the higher kind takes the band.
  @Test func cardsNeverStack() {
    let pairs: [(Facts, TonightBand.Item)] = [
      (
        facts {
          $0.location = true
          $0.setup = .home
        }, .location
      ),
      (
        facts {
          $0.location = true
          $0.flow = "fit"
        }, .location
      ),
      (
        facts {
          $0.location = true
          $0.gapWeek = true
        }, .location
      ),
      (
        facts {
          $0.gapWeek = true
          $0.setup = .headsUp
        }, .card(.gapWeek)
      ),
      (
        facts {
          $0.gapWeek = true
          $0.flow = "fit"
        }, .card(.gapWeek)
      ),
      (
        facts {
          $0.flow = "fit"
          $0.setup = .home
        }, .flow("fit")
      ),
    ]
    for (pair, item) in pairs { #expect(band(pair, 15) == [item]) }
    // In the gap: a problem, else Before bed's card, else nothing.
    let gap = facts {
      $0.nightOn = true
      $0.blocking = true
      $0.beforeBed = true
      $0.setup = .home
      $0.flow = "fit"
      $0.lastNight = true
    }
    #expect(band(gap, 22, 15) == [.card(.beforeBed)])
    var warned = gap
    warned.recovered = true
    #expect(band(warned, 22, 15) == [.recovered])
  }

  /// Never more than two, whatever is due.
  @Test func neverMoreThanTwo() {
    let everything = facts {
      $0.screenTimeOff = true
      $0.location = true
      $0.gapWeek = true
      $0.flow = "fit"
      $0.setup = .home
      $0.lastNight = true
    }
    for hour in 0..<24 {
      #expect(band(everything, hour).count <= 2)
      #expect(band(everything, hour).first == .screenTimeOff)
    }
  }

  // MARK: Through the snapshot

  /// The location note no longer hides last night: the row sits under it.
  @Test func aProblemKeepsLastNightsRow() {
    var state = setUp()
    state.setupFinishedAt = date(2026, 11, 10, 12)
    state.location = .scheduleOnly
    let log = [
      Transition(
        at: date(2026, 11, 16, 22, 30), cause: .windowStart, blockOn: true, changed: true,
        home: true, inWindow: true, entitled: true, active: [BlockID("sleep")]),
      Transition(
        at: date(2026, 11, 17, 7), cause: .windowEnd, blockOn: false, changed: true, home: true,
        inWindow: false, entitled: true),
    ]
    let home = HomeSnapshot(
      state: state, log: log, now: date(2026, 11, 17, 8, 10), calendar: london)
    #expect(home.band.items == [.location, .lastNight])
    #expect(home.lastNightCard)
    #expect(home.card == nil)
  }

  /// An hour before the lock, the offer waits for tomorrow; a build that can't save says so.
  @Test func theSnapshotKeepsTheNightsHour() {
    var state = setUp()
    state.setupFinishedAt = date(2026, 11, 10, 12)
    state.blocks = [sleepBlock(place: nil)]
    let at = { (hour: Int, minute: Int) in
      HomeSnapshot(state: state, log: [], now: date(2026, 11, 17, hour, minute), calendar: london)
    }
    #expect(at(21, 29).card == .home)
    #expect(at(21, 30).card == nil)
    #expect(at(21, 30).band.isEmpty)
    let readOnly = HomeSnapshot(
      state: state, log: [], now: date(2026, 11, 17, 15), calendar: london, readOnly: true)
    #expect(readOnly.band.items == [.readOnly])
    let flow = HomeSnapshot(
      state: state, log: [], now: date(2026, 11, 17, 15), calendar: london, flow: "fit")
    #expect(flow.band.items == [.flow("fit")])
    #expect(flow.card == nil)
  }
}
