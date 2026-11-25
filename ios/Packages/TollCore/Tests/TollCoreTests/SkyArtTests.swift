import Foundation
import Testing

@testable import TollCore

/// Your sky's true details: the moon as it was, the light of the hour, each star's real colour, the
/// fixed dust, which star a tap means, and which night a star stands for.
struct SkyArtTests {
  /// Published new and full moons (UTC, from eclipses, whose times are exact): the mean month lands
  /// within a day of each.
  @Test(arguments: [
    ("2017-08-21T18:30:00Z", 0.0), ("2024-04-08T18:21:00Z", 0.0), ("2026-08-12T17:37:00Z", 0.0),
    ("2022-11-08T11:02:00Z", 0.5), ("2025-03-14T06:55:00Z", 0.5),
  ])
  func moonOnKnownDates(_ when: String, _ phase: Double) throws {
    let moment = try #require(ISO8601DateFormatter().date(from: when))
    let moon = Moon(at: moment)
    let target = phase * Moon.month
    let off = abs(moon.age - target)
    #expect(min(off, Moon.month - off) < 1)
    if phase == 0 { #expect(moon.fraction < 0.02) } else { #expect(moon.fraction > 0.98) }
  }

  /// A waxing moon is lit on the right in the north and on the left in the south; waning, the
  /// other way. A quarter is half lit.
  @Test func moonsLitSide() throws {
    let firstQuarter = try #require(ISO8601DateFormatter().date(from: "2024-04-15T19:13:00Z"))
    let north = Moon(at: firstQuarter)
    #expect(north.waxing && north.litOnRight)
    #expect(abs(north.fraction - 0.5) < 0.12)
    #expect(!Moon(at: firstQuarter, southern: true).litOnRight)
    let waning = Moon(at: firstQuarter.addingTimeInterval(15 * 86_400))
    #expect(!waning.waxing && !waning.litOnRight)
    #expect(Moon(at: firstQuarter.addingTimeInterval(15 * 86_400), southern: true).litOnRight)
  }

  /// Last night's moon is the one at the latest midnight, morning or evening.
  @Test func lastNightsMoon() {
    let morning = Moon.lastNight(before: date(2026, 11, 25, 8), calendar: london, southern: false)
    let evening = Moon.lastNight(before: date(2026, 11, 25, 20), calendar: london, southern: false)
    #expect(morning == evening)
    #expect(morning == Moon(at: date(2026, 11, 25, 0)))
  }

  /// Three lights by the hour the screen opens, with the hours from config.
  @Test func lightByHour() {
    func light(_ hour: Int, _ config: TollConfig = .defaults) -> SkyLight {
      SkyLight(at: date(2026, 11, 25, hour), calendar: london, config: config)
    }
    #expect([16, 19, 20].map { light($0) } == [.evening, .evening, .evening])
    #expect([21, 23, 0, 4].map { light($0) } == [.night, .night, .night, .night])
    #expect([5, 8, 12, 15].map { light($0) } == [.morning, .morning, .morning, .morning])
    var config = TollConfig.defaults
    config.sky.nightFromHour = 22
    #expect(light(21, config) == .evening)
  }

  /// Colour follows B–V: Betelgeuse (1.85) warm, Rigel (−0.03) blue-white, and the tint is subtle.
  @Test func starColour() throws {
    let stars = SkyCatalogue.stars
    let betelgeuse = try #require(stars.first { $0.hr == 2061 })
    let rigel = try #require(stars.first { $0.hr == 1713 })
    #expect(betelgeuse.bv == 1.85 && rigel.bv == -0.03)
    let warm = StarColour.rgb(bv: betelgeuse.bv)
    let cool = StarColour.rgb(bv: rigel.bv)
    #expect(warm.red > warm.blue + 0.4)
    #expect(cool.blue > cool.red)
    #expect(StarColour.rgb(bv: 9) == StarColour.rgb(bv: 2))
    let tint = StarColour.tint(bv: betelgeuse.bv)
    #expect(tint.red - tint.blue < warm.red - warm.blue)
    #expect(stars.allSatisfy { (-0.4...2.0).contains($0.bv) })
  }

  /// The dust is fixed: the same every time, inside the sky, and gathered along the band.
  @Test func dustIsFixed() {
    let again = SkyDust.make(seed: 0x00D5_5C1E, count: 260, inBand: 0.45)
    #expect(SkyDust.motes == again)
    #expect(SkyDust.motes.count > 200)
    #expect(SkyDust.motes.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
    #expect(SkyDust.motes.allSatisfy { $0.brightness < 0.4 })
    let near = SkyDust.motes.filter { SkyDust.distanceFromBand(x: $0.x, y: $0.y) < 0.15 }.count
    let even = SkyDust.make(seed: 1, count: 260, inBand: 0)
      .filter { SkyDust.distanceFromBand(x: $0.x, y: $0.y) < 0.15 }.count
    #expect(near > even)
  }

  /// A tap finds the nearest lit star within 22 points, where the drawing puts it.
  @Test func tapFindsTheNearestStar() {
    let drawing = Sky(nights: 7, newestIsNew: false).drawing
    let layout = SkyLayout(
      bounds: drawing.bounds, fieldX: 0, fieldY: 100, fieldWidth: 390, fieldHeight: 220)
    let star = drawing.stars[3]
    let x = layout.x(star.x)
    let y = layout.y(star.y)
    #expect(y >= 100 && y <= 320)
    #expect(layout.nearest(drawing.stars, x: x + 5, y: y - 5) == 3)
    #expect(layout.nearest(drawing.stars, x: x, y: y + 400) == nil)
    #expect(layout.nearest(drawing.stars, x: -50, y: -50) == nil)
  }

  // MARK: A star's night

  var state: DuskState {
    var s = setUp()
    s.setupFinishedAt = date(2026, 1, 1, 12)
    return s
  }

  func history(_ count: Int, before: Date) -> [PastNight] {
    (1...count).map { back in
      let night = london.startOfDay(for: before.addingTimeInterval(-Double(back) * 86_400))
      let start = night.addingTimeInterval(22.25 * 3600)
      return PastNight(night: night, ran: true, start: start, end: start.addingTimeInterval(31_500))
    }
  }

  /// A star shows the night that lit it; past the table, the latest of its nights.
  @Test func eachStarIsANight() throws {
    let now = date(2026, 11, 25, 8)
    func sleep(_ nights: Int) -> YourSleep {
      YourSleep(
        state: state, log: [], history: history(nights, before: now), now: now, calendar: london)
    }
    let five = sleep(5)
    let first = try #require(five.starNight(0, calendar: london))
    #expect(first.day == Copy.Sky.night(date(2026, 11, 20, 0), calendar: london))
    #expect(
      first.locked
        == Copy.Sky.locked(
          Copy.time(date(2026, 11, 20, 22, 15), in: london),
          Copy.time(date(2026, 11, 21, 7), in: london)))
    #expect(five.starNight(4, calendar: london)?.day == Copy.Sky.night(date(2026, 11, 24, 0)))
    #expect(five.starNight(5, calendar: london) == nil)
    // 180 nights: the first 30 stars are on their second pass and show that night.
    let second = sleep(180)
    #expect(second.sky.drawing.stars[0].times == 2)
    #expect(
      second.starNight(0, calendar: london)?.day
        == Copy.Sky.night(date(2026, 11, 25, 0).addingTimeInterval(-30 * 86_400), calendar: london))
    #expect(
      second.starNight(40, calendar: london)?.day
        == Copy.Sky.night(date(2026, 11, 25, 0).addingTimeInterval(-140 * 86_400), calendar: london)
    )
  }

  /// The snapshot carries last night's moon, from the night's place, and the hour's light.
  @Test func theSnapshotsMoonAndLight() {
    let now = date(2026, 11, 25, 8)
    let sky = YourSleep(
      state: state, log: [], history: history(3, before: now), now: now, calendar: london
    ).sky
    #expect(sky.moon == Moon(at: date(2026, 11, 25, 0)))
    #expect(sky.light == .morning)
  }

  /// The shared picture has the moon and the night's date.
  @Test func landmarkCarriesMoonAndDate() throws {
    let now = date(2026, 11, 25, 8)
    var dawn = state
    dawn.setupFinishedAt = date(2026, 11, 1, 12)
    let sky = YourSleep(
      state: dawn, log: [], history: history(7, before: now), now: now, calendar: london
    ).sky
    let landmark = try #require(sky.landmark)
    #expect(landmark.moon == sky.moon)
    #expect(landmark.date == Copy.Sky.date(date(2026, 11, 24, 0), calendar: london))
  }
}
