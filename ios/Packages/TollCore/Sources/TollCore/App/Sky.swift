import Foundation

/// Your sky (D79): each night the lock ran lights one star, in a fixed order that completes real
/// constellations. It only adds: a night away, off or after the free week leaves it as it was, and
/// every night is one equal star. Only lit stars and the lines between them are drawn, never what
/// is left. Delight, not a lever: nothing here counts what's left or names the next landmark.
public struct Sky: Equatable, Sendable {
  public struct Star: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var magnitude: Double
    /// Its real B–V colour index, for a subtle tint (`StarColour`).
    public var bv: Double
    /// Once every star is lit, nights light them again in the same order, each pass a little
    /// brighter, so the sky keeps adding after the table runs out.
    public var times: Int
  }

  /// A line between two stars, as indexes into `Drawing.stars`.
  public struct Line: Equatable, Sendable {
    public var from: Int
    public var to: Int
  }

  /// The part of the sky to frame, in the stars' units (widths of the sky).
  public struct Bounds: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
  }

  /// A completed constellation's name, set beside it as a chart sets it: anchored at the middle of
  /// the figure's lowest star (`above` false) or highest (`above` true), whichever side is clearer.
  public struct Name: Equatable, Sendable {
    public var constellation: Constellation
    public var text: String
    public var x: Double
    public var y: Double
    public var above: Bool
  }

  /// What a view draws: lit stars, the lines between lit stars, the newest star while it's new, and
  /// the names of completed figures. Incomplete figures get no name.
  public struct Drawing: Equatable, Sendable {
    public var stars: [Star]
    public var lines: [Line]
    public var newest: Int?
    public var bounds: Bounds
    public var names: [Name] = []
  }

  /// A landmark morning (7, 30, 100 and 365 nights): one quiet line, the newly completed shape and
  /// a picture the person may share. Only while last night's star is new.
  public struct Landmark: Equatable, Sendable {
    public var nights: Int
    /// "30 nights. Orion is in your sky."
    public var line: String
    /// The constellation last night's star completed, alone; the whole sky when it completed none.
    public var shape: Drawing
    /// The whole sky, for the shared picture.
    public var sky: Drawing
    /// "30 nights locked", under the sky in the shared picture.
    public var number: String
    /// Last night's moon, in the shared picture too.
    public var moon: Moon?
    /// The poster's small date: the night the landmark was reached ("24 November 2026").
    public var date: String?
  }

  public var nights: Int
  public var drawing: Drawing
  public var constellations: Int
  public var landmark: Landmark?
  /// "Your sky. 23 nights locked. 3 constellations: the Big Dipper, Cassiopeia, the Little Dipper."
  public var spoken: String
  /// Last night's moon, as it really was; nil only where no date was given (tests).
  public var moon: Moon?
  /// The glow at the horizon, by the phone's hour when the screen opened.
  public var light: SkyLight

  /// `newestIsNew`: last night's star is still new, until the next night starts.
  public init(
    nights: Int, newestIsNew: Bool, moon: Moon? = nil, light: SkyLight = .night,
    config: TollConfig = .defaults
  ) {
    self.moon = moon
    self.light = light
    let table = SkyCatalogue.stars
    let nights = max(0, nights)
    self.nights = nights
    let lit = min(nights, table.count)
    let stars = table.prefix(lit).enumerated().map { index, star in
      Star(
        x: star.x, y: star.y, magnitude: star.magnitude, bv: star.bv,
        times: (nights - 1 - index) / table.count + 1)
    }
    let lines = SkyCatalogue.figures.flatMap(\.lines)
      .filter { $0.0 < lit && $0.1 < lit }
      .map { Line(from: $0.0, to: $0.1) }
    let newest = newestIsNew && nights > 0 ? (nights - 1) % table.count : nil
    let completed = SkyCatalogue.figures.filter { $0.stars.upperBound <= lit }
    drawing = Drawing(
      stars: stars, lines: lines, newest: newest, bounds: Self.frame(stars),
      names: completed.map { Self.name($0, stars: stars) })
    constellations = completed.count
    spoken = Copy.Sky.spoken(nights: nights, completed: completed.map(\.constellation))

    landmark = nil
    guard let newest, config.sky.landmarks.contains(nights) else { return }
    let figure = SkyCatalogue.figures.first { $0.stars.upperBound - 1 == newest }
    landmark = Landmark(
      nights: nights,
      line: Copy.Sky.landmark(nights, completed: figure?.constellation),
      shape: figure.map { Self.shape($0, stars: stars, newest: newest) } ?? drawing, sky: drawing,
      number: Copy.Sky.number(nights), moon: moon)
  }

  /// Whether the newest star fades in (design §2.5): the first time the sky is seen after the
  /// night that lit it. `seen` is the count the sky last showed.
  public func fadesIn(seen: Int) -> Bool {
    drawing.newest != nil && seen < nights
  }

  /// The part of the sky that holds the lit stars, at the sky's own shape: close in while there
  /// are few, so the first week's Big Dipper reads, widening as the sky fills, never past it. It
  /// changes only when a star is added.
  static func frame(_ stars: [Star]) -> Bounds {
    let aspect = SkyCatalogue.aspect
    guard let first = stars.first else { return Bounds(x: 0, y: 0, width: 1, height: aspect) }
    let pad = 0.07
    var minX = first.x
    var maxX = first.x
    var minY = first.y
    var maxY = first.y
    for star in stars {
      minX = min(minX, star.x)
      maxX = max(maxX, star.x)
      minY = min(minY, star.y)
      maxY = max(maxY, star.y)
    }
    let width = min(1, max(0.5, maxX - minX + 2 * pad, (maxY - minY + 2 * pad) / aspect))
    let height = width * aspect
    let x = min(max(0, (minX + maxX - width) / 2), 1 - width)
    let y = min(max(0, (minY + maxY - height) / 2), aspect - height)
    return Bounds(x: x, y: y, width: width, height: height)
  }

  /// A figure's name goes under it unless more of the other lit stars crowd that side; a chart's
  /// convention, not a rule of the sky.
  static func name(_ figure: SkyFigure, stars: [Star]) -> Name {
    let own = Set(figure.stars).union(figure.lines.flatMap { [$0.0, $0.1] })
    let picked = own.filter { $0 < stars.count }.map { stars[$0] }
    let xs = picked.map(\.x)
    let ys = picked.map(\.y)
    let x = ((xs.min() ?? 0) + (xs.max() ?? 0)) / 2
    let text = Copy.Sky.chartName(figure.constellation)
    // About how much sky the name covers at the whole sky's scale: 11 pt letters on 390 pt.
    let half = Double(text.count) * 0.0085
    func crowd(_ y: Double, _ above: Bool) -> Int {
      let top = above ? y - 0.05 : y
      return stars.indices.filter { index in
        !own.contains(index) && abs(stars[index].x - x) < half + 0.01
          && (top...(top + 0.05)).contains(stars[index].y)
      }.count
    }
    let below = ys.max() ?? 0
    let over = ys.min() ?? 0
    let above = crowd(over, true) < crowd(below, false)
    return Name(
      constellation: figure.constellation, text: text, x: x, y: above ? over : below,
      above: above)
  }

  /// One figure alone, framed around its own stars with a little room.
  static func shape(_ figure: SkyFigure, stars: [Star], newest: Int) -> Drawing {
    let indexes = Array(
      Set(figure.stars).union(figure.lines.flatMap { [$0.0, $0.1] }).filter { $0 < stars.count }
    ).sorted()
    let position = Dictionary(uniqueKeysWithValues: indexes.enumerated().map { ($1, $0) })
    let picked = indexes.map { stars[$0] }
    let lines = figure.lines.compactMap { line in
      position[line.0].flatMap { from in position[line.1].map { Line(from: from, to: $0) } }
    }
    let xs = picked.map(\.x)
    let ys = picked.map(\.y)
    let minX = xs.min() ?? 0
    let minY = ys.min() ?? 0
    let width = (xs.max() ?? 0) - minX
    let height = (ys.max() ?? 0) - minY
    let pad = max(width, height) * 0.18 + 0.01
    return Drawing(
      stars: picked, lines: lines, newest: position[newest],
      bounds: Bounds(
        x: minX - pad, y: minY - pad, width: width + 2 * pad, height: height + 2 * pad))
  }
}

/// Every night the night's block ran (D69), from the night log and the transition log together, so
/// trimming the log never takes one away.
enum NightsRan {
  static func keys(
    state: DuskState, log: [Transition], history: [PastNight], now: Date, calendar: Calendar
  ) -> Set<Date> {
    Set(
      PastNight.merged(history: history, state: state, log: log, now: now, calendar: calendar)
        .filter(\.ran).map(\.night))
  }

  /// The newest star is new until the next night starts (D79), even when that night doesn't run.
  static func isNew(_ night: Date, sleep: Block?, now: Date, calendar: Calendar) -> Bool {
    guard let sleep,
      let day = calendar.date(byAdding: .day, value: 1, to: night),
      let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)
    else { return false }
    guard
      let next = sleep.schedule.nextStart(after: noon.addingTimeInterval(-1), calendar: calendar)
    else { return true }
    return now < next
  }

  /// The sky for these nights, as of `now`: last night's moon as seen from the night's place
  /// (north unless it's south of the equator), and the glow of the hour.
  static func sky(
    _ ran: Set<Date>, state: DuskState, now: Date, calendar: Calendar, config: TollConfig
  ) -> Sky {
    let sleep = state.sleepBlock
    let southern = (state.place(sleep?.place)?.latitude ?? 0) < 0
    var sky = Sky(
      nights: ran.count,
      newestIsNew: ran.max().map { isNew($0, sleep: sleep, now: now, calendar: calendar) } ?? false,
      moon: Moon.lastNight(before: now, calendar: calendar, southern: southern),
      light: SkyLight(at: now, calendar: calendar, config: config), config: config)
    if let night = ran.max() { sky.landmark?.date = Copy.Sky.date(night, calendar: calendar) }
    return sky
  }
}
