import Foundation
import Testing

@testable import TollCore

/// Last night's card leads with sleep when Health has it (#88), and the morning after the first
/// night offers Health once to someone who didn't choose it (#86).
struct MorningSleepTests {
  let sleep = BlockID("sleep")
  func plain(_ text: String) -> String { text.replacingOccurrences(of: "\u{202F}", with: " ") }

  func line(_ at: Date, _ cause: ReconcileCause, active: [BlockID]) -> Transition {
    Transition(
      at: at, cause: cause, blockOn: !active.isEmpty, changed: false, home: true,
      inWindow: true, entitled: true, active: active, screenTime: true)
  }

  /// The 16th's night, on at 10:30 pm and off at 7 am.
  var log: [Transition] {
    [
      line(date(2026, 11, 16, 22, 30), .windowStart, active: [sleep]),
      line(date(2026, 11, 17, 7), .windowEnd, active: []),
    ]
  }

  /// Set up on the 16th, so that night is the first; or earlier, so it isn't.
  func state(health: Bool, setup: Date = date(2026, 11, 16, 12)) -> DuskState {
    var s = setUp()
    s.setupFinishedAt = setup
    s.gap = Gap()
    s.health = health
    return s
  }

  /// The night log's record of the 16th, corrected with Health's sleep.
  var slept: PastNight {
    PastNight(
      night: date(2026, 11, 16, 0), ran: true, start: date(2026, 11, 16, 22, 30),
      end: date(2026, 11, 17, 7),
      slept: .init(
        onset: date(2026, 11, 16, 23, 20), wake: date(2026, 11, 17, 6, 55), minutes: 455))
  }

  func morning(_ state: DuskState, history: [PastNight] = []) throws -> Morning {
    try #require(
      HomeSnapshot(
        state: state, log: log, now: date(2026, 11, 17, 8, 10), calendar: london,
        history: history
      ).lastNight)
  }

  @Test func healthsSleepLeadsTheCard() throws {
    let night = try morning(state(health: true), history: [slept])
    let asleep = try #require(night.asleep)
    #expect(plain(asleep.line) == "Asleep 11:20 pm – 6:55 am · 7 h 35 m")
    #expect(night.status == "Asleep 7 h 35 m")
    #expect(night.statusSpoken == "Last night, asleep 7 hours 35 minutes")
    #expect(plain(asleep.spoken) == "Asleep from 11:20 pm to 6:55 am, 7 hours 35 minutes")
    // Within the lock's planned 10:30 pm – 7:00 am (no buffers here).
    #expect(abs(asleep.span.start - 50.0 / 510) < 0.001)
    #expect(abs(asleep.span.end - 505.0 / 510) < 0.001)
    #expect(night.asksHealth == false)
    #expect(night.healthEmpty == false)
  }

  /// A night the lock ran before the 16th, from the night log.
  let earlier = [PastNight(night: date(2026, 11, 14, 0), ran: true)]
  var setUpBefore: Date { date(2026, 11, 10, 12) }

  /// Without Health's sleep the card leads with the lock, as before.
  @Test func withoutSleepTheLockLeads() throws {
    let night = try morning(state(health: true, setup: setUpBefore), history: earlier)
    #expect(night.asleep == nil)
    #expect(night.status.hasPrefix("Locked"))
    #expect(night.healthEmpty == false)
  }

  /// The morning after the first night: someone who skipped Health is offered it once; someone
  /// who chose it and has nothing for the night is told so.
  @Test func theFirstMorningAsksOnce() throws {
    #expect(try morning(state(health: false)).asksHealth)
    #expect(try morning(state(health: true)).healthEmpty)
    let later = try morning(state(health: false, setup: setUpBefore), history: earlier)
    #expect(later.asksHealth == false)
  }

  /// Choosing Health after setup changes nothing about the night.
  @Test func choosingHealthKeepsTheNight() {
    var s = state(health: false)
    let before = s.blocks
    #expect(apply(.health(true), &s, date(2026, 11, 17, 8, 10)) == nil)
    #expect(s.health)
    #expect(s.blocks == before)
  }
}
