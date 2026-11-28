import Foundation
import Testing

@testable import TollCore

/// Your sleep's measures (#87): the person's first nights against the last judged week, a change
/// said only when it clears a floor and their own noise and held until the next Monday noon (#165),
/// nothing said with too few nights, and Dusk's own stand-ins without Health's sleep.
struct SleepTrendsTests {
  func plain(_ text: String) -> String { text.replacingOccurrences(of: "\u{202F}", with: " ") }

  /// A night in November that ran: asleep `onset` minutes after 11 pm for `asleep` minutes, or no
  /// Health sleep; with its reaches, last reach and pauses.
  func night(
    _ day: Int, onset: Int? = nil, asleep: Int = 450, reaches: Int = 0, reach: Int? = nil,
    pauses: Int = 0, ran: Bool = true
  ) -> PastNight {
    let eleven = date(2026, 11, day, 23)
    return PastNight(
      night: date(2026, 11, day, 0), ran: ran,
      slept: onset.map {
        PastNight.Slept(
          onset: eleven.addingTimeInterval(Double($0) * 60),
          wake: eleven.addingTimeInterval(Double($0 + asleep) * 60), minutes: asleep)
      },
      lastReach: reach.map { eleven.addingTimeInterval(Double($0) * 60) }, reaches: reaches,
      pauses: pauses)
  }

  /// Tuesday morning, after Monday the 30th's night: the last seven are the 24th to the 30th, and
  /// the judged week is Monday the 23rd's.
  let morning = date(2026, 12, 1, 9)

  func trends(_ nights: [PastNight], health: Bool = true) -> SleepTrends {
    SleepTrends(nights: nights, health: health, now: morning, calendar: london)
  }

  func measure(_ trends: SleepTrends, _ kind: SleepTrends.Kind) -> SleepTrends.Measure? {
    trends.measures.first { $0.kind == kind }
  }

  /// Two weeks from Monday the 16th and last night: the first seven at `first` minutes after 11 pm,
  /// the rest at `last`, each night `noise` minutes either side in turn, so every seven nights'
  /// average is exact.
  func twoWeeks(first: Int, last: Int, noise: Int = 10, asleep: (Int, Int) = (450, 450))
    -> [PastNight]
  {
    (16...30).map { day in
      let late = day <= 22
      let wobble = [-noise, noise, -noise, noise, -noise, noise, 0][(day - 16) % 7]
      return night(
        day, onset: (late ? first : last) + wobble, asleep: late ? asleep.0 : asleep.1)
    }
  }

  /// Falling asleep 30 minutes earlier than the first week, with ordinary noise, is said, with
  /// the toward glyph's way.
  @Test func anEarlierTimeIsSaid() throws {
    let asleepBy = try #require(measure(trends(twoWeeks(first: 45, last: 15)), .asleepBy))
    #expect(plain(asleepBy.value) == "11:15 pm")
    #expect(asleepBy.detail == "On average, last 7 nights")
    #expect(asleepBy.change?.way == .toward)
    #expect(asleepBy.change?.line == "30 min earlier than your first 7 nights")
    #expect(asleepBy.chart.values.count == 14)
    #expect(asleepBy.chart.style == .times)
    // 11:45 pm is 705 minutes after the night's noon.
    let firstLevel = SleepTrends.Band(low: 705, high: 705)
    #expect(asleepBy.chart.first == firstLevel)
    #expect(asleepBy.spoken.hasPrefix("Asleep by: 11:15"))
    #expect(asleepBy.context == "Locked 7 of the last 7 nights")
  }

  /// A shift smaller than the floor, or one lost in the person's own noise, is "about the same".
  @Test func smallOrNoisyChangesAreSteady() throws {
    let small = try #require(measure(trends(twoWeeks(first: 30, last: 20, noise: 0)), .asleepBy))
    #expect(small.change?.way == .steady)
    #expect(small.change?.line == "About the same as your first 7 nights")
    let noisy = try #require(measure(trends(twoWeeks(first: 40, last: 15, noise: 60)), .asleepBy))
    #expect(noisy.change?.way == .steady)
  }

  /// The line is judged at Monday noon and held all week, while the value moves each night; before
  /// the first Monday after the first week, there is no line.
  @Test func theLineIsJudgedOnceAWeek() throws {
    let nights = twoWeeks(first: 45, last: 15)
    let tuesday = try #require(measure(trends(nights), .asleepBy)?.change)
    let saturday = SleepTrends(
      nights: nights, health: true, now: date(2026, 12, 5, 9), calendar: london)
    #expect(measure(saturday, .asleepBy)?.change == tuesday)
    #expect(measure(saturday, .asleepBy)?.detail == "On average, last 3 nights")
    let sundayBefore = SleepTrends(
      nights: nights, health: true, now: date(2026, 11, 30, 11), calendar: london)
    #expect(measure(sundayBefore, .asleepBy)?.change == nil)
  }

  /// One wild night is set aside: it neither makes a change nor hides one.
  @Test func oneWildNightIsSetAside() throws {
    var flat = twoWeeks(first: 30, last: 30)
    flat[10] = night(26, onset: -270)
    #expect(measure(trends(flat), .asleepBy)?.change?.way == .steady)
    var moved = twoWeeks(first: 45, last: 15)
    moved[10] = night(26, onset: 315)
    #expect(measure(trends(moved), .asleepBy)?.change?.way == .toward)
  }

  /// Later is said too, as a plain fact against the person's own first nights.
  @Test func aLaterTimeIsAFact() throws {
    let later = try #require(measure(trends(twoWeeks(first: 0, last: 40)), .asleepBy))
    #expect(later.change?.way == .away)
    #expect(later.change?.line == "40 min later than your first 7 nights")
  }

  /// More time asleep: a length, the right way for this measure.
  @Test func moreTimeAsleep() throws {
    let nights = twoWeeks(first: 30, last: 30, asleep: (400, 440))
    let asleep = try #require(measure(trends(nights), .timeAsleep))
    #expect(asleep.value == "7 h 20 m")
    #expect(asleep.change?.way == .toward)
    #expect(asleep.change?.line == "40 min more than your first 7 nights")
    #expect(asleep.chart.style == .bars)
  }

  /// Too few nights: nothing at all; a few: values without a comparison.
  @Test func tooFewNightsSayNothing() throws {
    #expect(trends([night(29, onset: 30), night(30, onset: 20)]).isEmpty)
    let three = trends((28...30).map { night($0, onset: 30) })
    let asleepBy = try #require(measure(three, .asleepBy))
    #expect(asleepBy.change == nil)
    #expect(asleepBy.detail == "On average, last 3 nights")
    // How steady needs a week of nights before it says anything.
    #expect(measure(three, .steadiness) == nil)
  }

  /// How steady: two weeks against the first two, on each night's distance from the middle one.
  @Test func steadierIsSaidAsTheFirstSpread() throws {
    let nights = (1...30).map { day in
      night(day, onset: 30 + (day % 2 == 0 ? 1 : -1) * (day <= 14 ? 40 : 8))
    }
    let steady = try #require(measure(trends(nights), .steadiness))
    #expect(steady.value == "± 8 min")
    #expect(steady.change?.way == .toward)
    #expect(steady.change?.line == "From ± 40 min in your first 14 nights")
    #expect(steady.spoken.contains("within 8 min"))
  }

  /// Fewer reaches for a locked app, with the pauses beside them as context.
  @Test func fewerReachesWithPauses() throws {
    let nights = (16...30).map { day in
      night(day, onset: 30, reaches: day <= 22 ? 4 + day % 2 : 1, pauses: day == 27 ? 2 : 0)
    }
    let reaches = try #require(measure(trends(nights), .reaches))
    #expect(reaches.value == "1")
    #expect(reaches.change?.way == .toward)
    // The first week's 4, 5, 4, 5, 4, 5, 4 without its highest and lowest: 4.4.
    #expect(reaches.change?.line == "3.4 fewer a night than your first 7 nights")
    #expect(reaches.context == "2 pauses in the last 7 nights")
  }

  /// Without Health's sleep, Dusk's own nights stand in, named as what they are; whether Health
  /// was chosen decides only the note.
  @Test func withoutHealthDusksOwnNightsStandIn() throws {
    let nights = (16...30).map { day in
      night(day, reaches: 2, reach: day <= 22 ? 50 : 10, ran: day != 26)
    }
    let dusk = trends(nights, health: false)
    #expect(dusk.source == .dusk)
    #expect(dusk.measures.map(\.kind) == [.phoneDown, .nightsLocked, .phoneSteadiness, .reaches])
    let standIns = dusk.measures.prefix(3).allSatisfy { $0.standIn }
    #expect(standIns)
    let down = try #require(measure(dusk, .phoneDown))
    #expect(down.change?.line == "40 min earlier than your first 7 nights")
    let locked = try #require(measure(dusk, .nightsLocked))
    #expect(locked.value == "6 of 7")
    #expect(locked.detail == "The last 7 nights")
    #expect(locked.change?.way == .steady)
    #expect(trends(nights, health: true).source == .healthEmpty)
  }

  /// Health's sleep wins once the last week has a few nights of it.
  @Test func healthLeadsWhenItHasTheNights() {
    let nights = (16...30).map { night($0, onset: $0 >= 28 ? 30 : nil, reach: 10) }
    #expect(trends(nights).source == .health)
    #expect(trends(nights).measures.first?.kind == .asleepBy)
  }

  /// A record corrected with Health's sleep reads back with it, and with Dusk's own signals.
  @Test func aRecordReadsBackWithSleepAndReaches() throws {
    let facts = NightFacts(
      night: date(2026, 11, 16, 0), plannedStart: date(2026, 11, 16, 22),
      plannedEnd: date(2026, 11, 17, 7, 15), bed: date(2026, 11, 16, 22, 30),
      wake: date(2026, 11, 17, 7), gap: 30, blockStart: date(2026, 11, 16, 22),
      blockEnd: date(2026, 11, 17, 7, 15), away: false, paused: false, screenTimeOff: false,
      stops: 2, doorAsks: 1, lastReach: date(2026, 11, 16, 23, 40), unlocksUsed: 1,
      unlocksReturned: 0, weekend: false)
    let line = try #require(NightRecordLine.encode(facts, calendar: london, model: stamp))
    let slept = SleepNight(
      night: date(2026, 11, 16, 0), onset: date(2026, 11, 16, 23, 20),
      wake: date(2026, 11, 17, 6, 55), asleepMinutes: 455, awakeMinutes: 20, source: .watch)
    let corrected = try #require(NightRecordLine.corrected(line, with: slept, calendar: london))
    let past = try #require(NightRecordLine.past(corrected, calendar: london))
    #expect(past.slept == .init(onset: slept.onset, wake: slept.wake, minutes: 455))
    #expect(past.lastReach == date(2026, 11, 16, 23, 40))
    #expect(past.reaches == 3)
    #expect(past.pauses == 1)
    #expect(NightRecordLine.past(line, calendar: london)?.slept == nil)
  }
}
