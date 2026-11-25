import Foundation
import Testing

@testable import TollCore

/// Your sky (D79): one star a night in a fixed order, only lit stars and the lines between them,
/// constellations counted, the newest star new until the next night, and landmark mornings at 7,
/// 30, 100 and 365 nights.
struct SkyTests {
  @Test func oneStarForEachNight() {
    #expect(Sky(nights: 0, newestIsNew: false).drawing.stars.isEmpty)
    let five = Sky(nights: 5, newestIsNew: false)
    #expect(five.drawing.stars.count == 5)
    #expect(five.drawing.stars.allSatisfy { $0.times == 1 })
    // The Big Dipper's bowl and the first star of its handle: only lines between lit stars.
    #expect(five.drawing.lines.count == 5)
    #expect(five.drawing.lines.allSatisfy { $0.from < 5 && $0.to < 5 })
    #expect(Sky(nights: 150, newestIsNew: false).drawing.stars.count == 150)
  }

  /// Past the table, nights light the stars again in the same order: it only ever adds.
  @Test func pastTheTableStarsBrighten() {
    let sky = Sky(nights: 152, newestIsNew: true)
    #expect(sky.drawing.stars.count == 150)
    #expect(sky.drawing.stars.prefix(2).allSatisfy { $0.times == 2 })
    #expect(sky.drawing.stars.dropFirst(2).allSatisfy { $0.times == 1 })
    #expect(sky.drawing.newest == 1)
    #expect(Sky(nights: 301, newestIsNew: false).drawing.stars.first?.times == 3)
  }

  /// Close in on a few stars, at the sky's shape, and widen to the whole sky as it fills.
  @Test func theFrameHoldsTheLitStars() {
    for nights in [1, 5, 30, 100] {
      let drawing = Sky(nights: nights, newestIsNew: false).drawing
      let frame = drawing.bounds
      #expect(abs(frame.height / frame.width - SkyCatalogue.aspect) < 1e-9)
      #expect(frame.x >= 0 && frame.x + frame.width <= 1 + 1e-9)
      #expect(frame.y >= 0 && frame.y + frame.height <= SkyCatalogue.aspect + 1e-9)
      #expect(
        drawing.stars.allSatisfy {
          $0.x >= frame.x && $0.x <= frame.x + frame.width && $0.y >= frame.y
            && $0.y <= frame.y + frame.height
        })
    }
    #expect(Sky(nights: 5, newestIsNew: false).drawing.bounds.width == 0.5)
    #expect(Sky(nights: 150, newestIsNew: false).drawing.bounds.width == 1)
  }

  @Test func completedConstellations() {
    let counts = [6, 7, 12, 19, 29, 30, 100, 150, 400].map {
      Sky(nights: $0, newestIsNew: false).constellations
    }
    #expect(counts == [0, 1, 2, 3, 3, 4, 14, 23, 23])
  }

  /// The order completes a real shape exactly at each early landmark.
  @Test func landmarksCompleteAShape() throws {
    let seven = try #require(Sky(nights: 7, newestIsNew: true).landmark)
    #expect(seven.line == "7 nights. The Big Dipper is in your sky.")
    #expect(seven.number == "7 nights locked")
    #expect(seven.shape.stars.count == 7)
    #expect(seven.shape.lines.count == 7)
    #expect(seven.shape.newest == 6)
    #expect(Sky(nights: 30, newestIsNew: true).landmark?.line == "30 nights. Orion is in your sky.")
    #expect(
      Sky(nights: 100, newestIsNew: true).landmark?.line == "100 nights. Pegasus is in your sky.")
    // At 365 last night's star completed no shape: the whole sky.
    let year = try #require(Sky(nights: 365, newestIsNew: true).landmark)
    #expect(year.line == "365 nights in your sky.")
    #expect(year.shape.stars.count == 150)
  }

  /// A landmark is only the morning it's reached, until the next night: never before, never
  /// after, and no other count is one.
  @Test func landmarksOnlyWhileNew() {
    #expect(Sky(nights: 7, newestIsNew: false).landmark == nil)
    for nights in [1, 6, 8, 29, 31, 99, 150, 364] {
      #expect(Sky(nights: nights, newestIsNew: true).landmark == nil)
    }
  }

  @Test func newestStarAndItsFade() {
    let sky = Sky(nights: 23, newestIsNew: true)
    #expect(sky.drawing.newest == 22)
    #expect(sky.fadesIn(seen: 22))
    #expect(!sky.fadesIn(seen: 23))
    let old = Sky(nights: 23, newestIsNew: false)
    #expect(old.drawing.newest == nil)
    #expect(!old.fadesIn(seen: 0))
  }

  /// One element for VoiceOver, naming the completed shapes; the empty sky says its one line.
  @Test func spoken() {
    #expect(
      Sky(nights: 23, newestIsNew: false).spoken
        == "Your sky. 23 nights locked. 3 constellations: the Big Dipper, Cassiopeia, the Little "
        + "Dipper.")
    #expect(
      Sky(nights: 7, newestIsNew: false).spoken
        == "Your sky. 7 nights locked. 1 constellation: the Big Dipper.")
    #expect(Sky(nights: 1, newestIsNew: false).spoken == "Your sky. 1 night locked.")
    #expect(
      Sky(nights: 0, newestIsNew: false).spoken
        == "Your sky. Your first star comes with your first locked night.")
  }

  /// Only a completed figure is named, beside its own stars, as a chart sets it.
  @Test func namesOnlyCompleteFigures() throws {
    #expect(Sky(nights: 6, newestIsNew: false).drawing.names.isEmpty)
    let thirty = Sky(nights: 30, newestIsNew: false).drawing
    #expect(
      thirty.names.map(\.constellation) == [.bigDipper, .cassiopeia, .littleDipper, .orion])
    let dipper = try #require(thirty.names.first)
    #expect(dipper.text == "Big Dipper")
    let stars = thirty.stars.prefix(7)
    #expect(dipper.top == stars.map(\.y).min() && dipper.bottom == stars.map(\.y).max())
    #expect(dipper.x > stars.map(\.x).min() ?? 0 && dipper.x < stars.map(\.x).max() ?? 1)
    #expect(Sky(nights: 150, newestIsNew: false).drawing.names.count == 23)
  }

  /// The table: contiguous figures, lines that only reach back, every star inside the sky.
  @Test func catalogueHolds() {
    let stars = SkyCatalogue.stars
    #expect(stars.count == 150)
    var next = 0
    for figure in SkyCatalogue.figures {
      #expect(figure.stars.lowerBound == next)
      next = figure.stars.upperBound
      for line in figure.lines {
        #expect(figure.stars.contains(max(line.0, line.1)))
      }
    }
    #expect(next == stars.count)
    #expect(Set(SkyCatalogue.figures.map(\.constellation)).count == Constellation.allCases.count)
    #expect(stars.allSatisfy { (0...1).contains($0.x) && (0...SkyCatalogue.aspect).contains($0.y) })
  }

  // MARK: Nights, from the logs

  let sleep = BlockID("sleep")

  func nights(_ days: [Int]) -> [Transition] {
    days.flatMap {
      [
        Transition(
          at: date(2026, 11, $0, 22, 30), cause: .windowStart, blockOn: true, changed: true,
          home: true, inWindow: true, entitled: true, active: [sleep]),
        Transition(
          at: date(2026, 11, $0 + 1, 7), cause: .windowEnd, blockOn: false, changed: true,
          home: true, inWindow: false, entitled: true, active: []),
      ]
    }
  }

  var state: DuskState {
    var s = setUp()
    s.setupFinishedAt = date(2026, 10, 30, 12)
    return s
  }

  /// The newest star is new from the morning until the next night starts.
  @Test func newUntilTheNextNight() {
    let log = nights([17, 18, 19])
    func sky(_ now: Date) -> Sky {
      YourSleep(state: state, log: log, history: [], now: now, calendar: london).sky
    }
    #expect(sky(date(2026, 11, 20, 8)).drawing.newest == 2)
    #expect(sky(date(2026, 11, 20, 22)).drawing.newest == 2)
    #expect(sky(date(2026, 11, 20, 23)).drawing.newest == nil)
    #expect(sky(date(2026, 11, 20, 23)).nights == 3)
  }

  /// Last night was the seventh: the morning card carries the landmark, counting the night log.
  @Test func aLandmarkMorning() throws {
    let history = (11...16).map { PastNight(night: date(2026, 11, $0, 0), ran: true) }
    let morning = try #require(
      HomeSnapshot(
        state: state, log: nights([17]), now: date(2026, 11, 18, 9), calendar: london,
        history: history
      ).lastNight)
    #expect(morning.landmark?.nights == 7)
    let sixth = HomeSnapshot(
      state: state, log: nights([17]), now: date(2026, 11, 18, 9), calendar: london,
      history: Array(history.dropFirst()))
    #expect(sixth.lastNight != nil)
    #expect(sixth.lastNight?.landmark == nil)
  }
}
