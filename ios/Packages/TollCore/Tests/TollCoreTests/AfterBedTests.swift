import Foundation
import Testing

@testable import TollCore

/// What the app asks Apple's report for (#65): last night, bed to wake.
struct AfterBedTests {
  func setUp(at setup: Date) -> DuskState {
    var state = TollCoreTests.setUp()
    state.setupFinishedAt = setup
    return state
  }

  @Test func lastNightIsBedToWake() {
    let s = setUp(at: date(2026, 11, 14, 20))
    let morning = AfterBed.lastNight(s, now: date(2026, 11, 17, 8, 10), calendar: london)
    #expect(morning == DateInterval(start: date(2026, 11, 16, 22, 30), end: date(2026, 11, 17, 7)))
    // During tonight, it is still the night that ended this morning.
    let tonight = AfterBed.lastNight(s, now: date(2026, 11, 17, 23, 40), calendar: london)
    #expect(tonight == morning)
  }

  @Test func nothingBeforeAFirstNightEnds() {
    let s = setUp(at: date(2026, 11, 17, 20))
    #expect(AfterBed.lastNight(s, now: date(2026, 11, 17, 23), calendar: london) == nil)
    var notSetUp = s
    notSetUp.setupFinishedAt = nil
    #expect(AfterBed.lastNight(notSetUp, now: date(2026, 11, 18, 8), calendar: london) == nil)
  }

  @Test func aNightSetUpPartWayStartsAtSetup() {
    let s = setUp(at: date(2026, 11, 17, 23))
    let night = AfterBed.lastNight(s, now: date(2026, 11, 18, 8), calendar: london)
    #expect(night?.start == date(2026, 11, 17, 23))
    #expect(night?.end == date(2026, 11, 18, 7))
  }

  @Test func theNumberIsShownAndSpoken() {
    #expect(AfterBed.shown(360) == ("6 m", "6 minutes"))
    #expect(AfterBed.shown(4_320) == ("1 h 12 m", "1 hour 12 minutes"))
    #expect(AfterBed.shown(0).spoken == "0 minutes")
  }
}
