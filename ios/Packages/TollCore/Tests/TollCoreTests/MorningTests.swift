import Foundation
import Testing

@testable import TollCore

/// The morning card (D65, #103): exact facts about last night, shown from the end of the night until
/// noon, and nothing when there's nothing new.
struct MorningTests {
  let sleep = BlockID("sleep")

  func line(
    _ at: Date, _ cause: ReconcileCause, active: [BlockID], home: Bool? = true,
    door: Door.Phase? = nil, screenTime: Bool? = true
  ) -> Transition {
    Transition(
      at: at, cause: cause, blockOn: !active.isEmpty, changed: false, home: home,
      inWindow: true, entitled: true, door: door, active: active, screenTime: screenTime)
  }

  /// The 16th's night: on at 10:30 pm, off at 7 am, with these taps and anything else.
  func night(taps: Int = 0, extra: [Transition] = []) -> [Transition] {
    var log = [
      line(date(2026, 11, 16, 22, 30), .windowStart, active: [sleep]),
      line(date(2026, 11, 17, 7), .windowEnd, active: []),
    ]
    for tap in 0..<taps {
      log.append(line(date(2026, 11, 16, 23, tap * 10), .blockScreen, active: [sleep]))
    }
    return (log + extra).sorted { $0.at < $1.at }
  }

  var state: DuskState {
    var s = setUp()
    s.setupFinishedAt = date(2026, 11, 10, 12)
    return s
  }

  func home(_ now: Date, _ log: [Transition], state: DuskState? = nil) -> HomeSnapshot {
    HomeSnapshot(state: state ?? self.state, log: log, now: now, calendar: london)
  }

  @Test func lastNightFromItsEndUntilNoon() throws {
    let log = night(taps: 3)
    let morning = try #require(home(date(2026, 11, 17, 9), log).morning)
    #expect(morning.outcome == .ran)
    #expect(morning.ran == [.init(start: 0, end: 1)])
    #expect(morning.gaps.isEmpty)
    #expect(morning.from.hasPrefix("10:30") || morning.from.hasPrefix("22:30"))
    #expect(morning.to.hasPrefix("7:00") || morning.to.hasPrefix("07:00"))
    #expect(morning.putDown == "You put it down 3 times")
    #expect(morning.eyebrow == "Apps locked last night")
    // Still the night, and from noon: Tonight looks ahead.
    #expect(home(date(2026, 11, 17, 6, 30), log).morning == nil)
    let noon = home(date(2026, 11, 17, 12), log)
    #expect(noon.morning == nil)
    #expect(noon.eyebrow == "Apps lock at")
  }

  /// Nothing new means nothing shown: no taps, no line.
  @Test func noTapsNoLine() throws {
    let morning = try #require(home(date(2026, 11, 17, 9), night()).morning)
    #expect(morning.putDown == nil)
    #expect(home(date(2026, 11, 17, 9), night(taps: 1)).morning?.putDown == "You put it down once")
  }

  /// "Unlock in Dusk" isn't putting it down (D46).
  @Test func onlyNeverMindCounts() {
    let log = night(extra: [line(date(2026, 11, 16, 23), .doorAsked, active: [sleep])])
    #expect(home(date(2026, 11, 17, 9), log).morning?.putDown == nil)
  }

  /// A pause lifts the shield, so the bar has a gap where it was open (D67).
  @Test func aPauseIsAGap() throws {
    let log = night(extra: [
      line(date(2026, 11, 17, 0, 40), .doorStart, active: [sleep], door: .open),
      line(date(2026, 11, 17, 0, 50), .doorEnd, active: [sleep]),
    ])
    let morning = try #require(home(date(2026, 11, 17, 9), log).morning)
    #expect(morning.ran.count == 2)
    #expect(morning.gaps.count == 1)
    let start = 130.0 / 510
    #expect(abs((morning.gaps.first?.start ?? 0) - start) < 0.0001)
    #expect(abs((morning.gaps.first?.end ?? 0) - 140.0 / 510) < 0.0001)
    #expect(
      morning.spoken.contains("open from 12:40") || morning.spoken.contains("open from 00:40"))
  }

  /// An away night is named, never "missed" (D65).
  @Test func anAwayNightIsNamed() throws {
    let log = [
      line(date(2026, 11, 16, 22, 30), .windowStart, active: [], home: false),
      line(date(2026, 11, 17, 7), .windowEnd, active: [], home: false),
    ]
    let morning = try #require(home(date(2026, 11, 17, 9), log).morning)
    #expect(morning.outcome == .away)
    #expect(morning.ran.isEmpty)
    #expect(morning.putDown == nil)
    #expect(morning.spoken.contains("Away from home"))
    // Nothing was locked, so the eyebrow doesn't say it was; the line says why.
    #expect(morning.eyebrow == "Last night")
  }

  @Test func screenTimeOffIsNamed() {
    let log = [
      line(date(2026, 11, 16, 22, 30), .windowStart, active: [sleep], screenTime: false),
      line(date(2026, 11, 17, 0, 10), .blockScreen, active: [sleep], screenTime: false),
    ]
    let morning = home(date(2026, 11, 17, 9), log).morning
    #expect(morning?.outcome == .noScreenTime)
    #expect(morning?.putDown == nil)
  }

  /// A bad night is neutral and forward-looking: a night that was due and didn't run shows no card,
  /// and Tonight says when tonight starts.
  @Test func aNightThatDidntRunShowsNothing() {
    let morning = home(date(2026, 11, 17, 9), [])
    #expect(morning.morning == nil)
    #expect(morning.eyebrow == "Apps lock at")
  }

  @Test func afterTheTrialTheMorningIsTheTrialsToSay() {
    var s = state
    s.trial.entitled = false
    #expect(home(date(2026, 11, 17, 9), night(taps: 2), state: s).morning == nil)
  }

  /// A weekday night seen on a Saturday afternoon starts on Monday: the eyebrow says so, and the
  /// line counts days rather than 55 hours (D75).
  @Test func aStartThatIsntTonightNamesItsDay() {
    var s = state
    s.blocks[0].schedule = WeeklySchedule(rules: [.init(days: Weekday.weekdays, window: usual)])
    #expect(home(date(2026, 11, 20, 15), [], state: s).eyebrow == "Apps lock at")
    let saturday = home(date(2026, 11, 21, 15), [], state: s)
    #expect(saturday.eyebrow == "Apps lock Monday at")
    #expect(
      saturday.hero
        == .tonight(start: date(2026, 11, 23, 22, 30), detail: "At home · starts in 2 d 7 h"))
    #expect(home(date(2026, 11, 22, 15), [], state: s).eyebrow == "Apps lock tomorrow at")
  }

  /// Filled when it ran; hollow when it didn't, with a mark for why; never a dash (D65).
  @Test func nightsReadAsDots() {
    typealias Bar = HomeSnapshot.Bar
    func dot(_ night: Bar.Night) -> Bar.Dot { Bar(day: "Mon", night: night, isLatest: false).dot }
    #expect(dot(.stopped(3)) == .ran)
    #expect(dot(.stopped(0)) == .ran)
    #expect(dot(.missed) == .hollow(nil))
    #expect(dot(.away) == .hollow(.away))
    #expect(dot(.off) == .hollow(.off))
    #expect(dot(.noScreenTime) == .hollow(.noScreenTime))
    #expect(dot(.ahead) == .ahead)
  }

  /// Facts, never praise; no streaks, no grades, no "missed"; the block isn't called Sleep (D65,
  /// D68).
  @Test func theWordsAreFacts() {
    let lines =
      [1, 3, 23].flatMap {
        [
          Copy.Morning.putDown($0), Copy.YourSleep.nights($0), Copy.YourSleep.lastWeek($0),
          Copy.YourSleep.best($0),
        ]
      } + [
        Copy.Morning.lastNight, Copy.Morning.away, Copy.Morning.noScreenTime,
        Copy.Morning.spokenRan(from: "10:30 pm", to: "7:00 am", gaps: [("1:00 am", "1:10 am")]),
        Copy.Morning.spokenAway(from: "10:30 pm", to: "7:00 am"),
        Copy.Morning.spokenNoScreenTime(from: "10:30 pm", to: "7:00 am"),
        Copy.YourSleep.newWeek, Copy.YourSleep.bestDetail, Copy.Morning.lockedLastNight,
      ]
    let banned = [
      "great", "well done", "nice", "good", "bad", "streak", "missed", "fail", "!", "sleep", "%",
      " of ",
    ]
    for line in lines {
      for word in banned { #expect(!line.lowercased().contains(word), "\(line)") }
    }
  }
}
