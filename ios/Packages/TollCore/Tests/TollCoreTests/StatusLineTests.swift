import Foundation
import Testing

@testable import TollCore

struct StatusLineTests {
  let london = calendar("Europe/London")

  func state(on: Bool = false, home: Bool? = true, check: HomeCheck = .location) -> SleepState {
    var state = SleepState()
    state.settings.window = usual
    state.blockOn = on
    state.blockEndsAt = on ? date(2026, 11, 18, 7) : nil
    state.presence = home.map { Presence(isHome: $0, at: date(2026, 11, 17, 20)) }
    state.homeCheck = check
    return state
  }

  @Test func blockedShowsTheEnd() {
    let line = StatusLine(state: state(on: true), now: date(2026, 11, 17, 23), calendar: london)
    #expect(line == .blocked(until: date(2026, 11, 18, 7)))
  }

  @Test func awayInsideTheWindow() {
    let line = StatusLine(state: state(home: false), now: date(2026, 11, 17, 23), calendar: london)
    #expect(line == .away)
  }

  @Test func awayInTheDayShowsTonight() {
    let line = StatusLine(state: state(home: false), now: date(2026, 11, 17, 15), calendar: london)
    #expect(line == .starts(at: date(2026, 11, 17, 22, 30), windowOnly: false))
  }

  @Test func windowOnlyDropsTheHomeCondition() {
    let line = StatusLine(
      state: state(home: false, check: .windowOnly), now: date(2026, 11, 18, 8), calendar: london)
    #expect(line == .starts(at: date(2026, 11, 18, 22, 30), windowOnly: true))
  }

  @Test func staleBlockIsNotShownAsBlocked() {
    let line = StatusLine(state: state(on: true), now: date(2026, 11, 18, 7, 30), calendar: london)
    #expect(line == .starts(at: date(2026, 11, 18, 22, 30), windowOnly: false))
  }
}
