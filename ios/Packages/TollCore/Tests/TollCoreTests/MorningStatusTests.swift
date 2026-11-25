import Foundation
import Testing

@testable import TollCore

/// Last night's card folds to one row each morning (founder, 25 Nov): the night's outcome at a
/// glance, a true length when it ran, and the landmark's line on a landmark morning.
struct MorningStatusTests {
  let sleep = BlockID("sleep")

  func line(
    _ at: Date, _ cause: ReconcileCause, active: [BlockID], home: Bool? = true,
    door: Door.Phase? = nil, screenTime: Bool? = true
  ) -> Transition {
    Transition(
      at: at, cause: cause, blockOn: !active.isEmpty, changed: false, home: home,
      inWindow: true, entitled: true, door: door, active: active, screenTime: screenTime)
  }

  /// The 16th's night, on at 10:30 pm and off at 7 am, with anything else.
  func night(_ extra: [Transition] = []) -> [Transition] {
    ([
      line(date(2026, 11, 16, 22, 30), .windowStart, active: [sleep]),
      line(date(2026, 11, 17, 7), .windowEnd, active: []),
    ] + extra).sorted { $0.at < $1.at }
  }

  func morning(_ log: [Transition]) throws -> Morning {
    var state = setUp()
    state.setupFinishedAt = date(2026, 11, 10, 12)
    return try #require(
      HomeSnapshot(state: state, log: log, now: date(2026, 11, 17, 9), calendar: london).lastNight)
  }

  @Test func aNightThatRanSaysHowLong() throws {
    let ran = try morning(night())
    #expect(ran.lockedMinutes == 510)
    #expect(ran.status == "Locked 8 h 30 m")
    #expect(ran.statusSpoken == "Last night, apps locked 8 hours 30 minutes")
  }

  /// A break still reads as a night that ran; the length leaves the break out, so it stays true.
  @Test func aBreakIsLeftOutOfTheLength() throws {
    let paused = try morning(
      night([
        line(date(2026, 11, 17, 0, 40), .doorStart, active: [sleep], door: .open),
        line(date(2026, 11, 17, 0, 50), .doorEnd, active: [sleep]),
      ]))
    #expect(paused.lockedMinutes == 500)
    #expect(paused.status == "Locked 8 h 20 m")
  }

  @Test func awayAndScreenTimeOffAreNamed() throws {
    let away = try morning([
      line(date(2026, 11, 16, 22, 30), .windowStart, active: [], home: false),
      line(date(2026, 11, 17, 7), .windowEnd, active: [], home: false),
    ])
    #expect(away.status == "Away, nothing locked")
    #expect(away.statusSpoken == "Last night, away from home, nothing locked")
    let off = try morning([
      line(date(2026, 11, 16, 22, 30), .windowStart, active: [sleep], screenTime: false),
      line(date(2026, 11, 17, 7), .windowEnd, active: [], screenTime: false),
    ])
    #expect(off.status == "Screen Time was off")
    #expect(off.statusSpoken == "Last night, Screen Time was off")
  }

  /// A landmark morning folds to the landmark's line; VoiceOver hears the length first.
  @Test func aLandmarkTakesTheLengthsPlace() throws {
    var landmark = try morning(night())
    landmark.landmark = Sky(nights: 30, newestIsNew: true).landmark
    let line = try #require(landmark.landmark?.line)
    #expect(landmark.status == line)
    #expect(landmark.statusSpoken == "Last night, apps locked 8 hours 30 minutes. \(line)")
  }

  @Test func lengthsAreSaidInWords() {
    #expect(Copy.Morning.spokenLocked(minutes: 45) == "apps locked 45 minutes")
    #expect(Copy.Morning.spokenLocked(minutes: 60) == "apps locked 1 hour")
    #expect(Copy.Morning.spokenLocked(minutes: 61) == "apps locked 1 hour 1 minute")
    #expect(Copy.Morning.spokenLocked(minutes: 0) == "apps locked 0 minutes")
    #expect(Copy.Morning.statusLocked(Copy.Home.duration(45 * 60)) == "Locked 45 m")
  }

  /// Facts, never grades (D65): the row's words pass the same test as the card's.
  @Test func theRowsWordsAreFacts() {
    let lines = [
      Copy.Morning.statusLocked("8 h 45 m"), Copy.Morning.statusAway,
      Copy.Morning.statusNoScreenTime, Copy.Morning.spokenStatusAway,
      Copy.Morning.spokenLocked(minutes: 525), Copy.Morning.folded, Copy.Morning.unfolded,
      Copy.Morning.unfoldHint, Copy.Morning.foldHint,
    ]
    let banned = ["great", "nice", "good", "bad", "streak", "missed", "fail", "!", "sleep", "%"]
    for line in lines {
      for word in banned { #expect(!line.lowercased().contains(word), "\(line)") }
    }
  }
}
