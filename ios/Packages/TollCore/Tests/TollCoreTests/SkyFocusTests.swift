import Testing

@testable import TollCore

/// Your sky's names and lines: faint until a tap brings them forward, a star's own figure while its
/// night is open, and nothing to brighten in an empty sky.
struct SkyFocusTests {
  /// Every star knows its figure, by the figure's range; a line knows its own, even where it reaches
  /// a star of an earlier figure.
  @Test func eachStarKnowsItsFigure() throws {
    #expect(SkyCatalogue.constellations.count == SkyCatalogue.stars.count)
    for figure in SkyCatalogue.figures {
      #expect(figure.stars.allSatisfy { SkyCatalogue.constellations[$0] == figure.constellation })
    }
    let drawing = Sky(nights: 150, newestIsNew: false).drawing
    #expect(drawing.stars[0].constellation == .bigDipper)
    #expect(drawing.stars[19].constellation == .orion)
    // Auriga's line to Elnath, Taurus's horn tip.
    let shared = try #require(drawing.lines.first { $0.from == 114 && $0.to == 64 })
    #expect(shared.constellation == .auriga)
    #expect(drawing.stars[64].constellation == .taurus)
  }

  /// Faint by default: nothing brightened.
  @Test func faintByDefault() {
    let drawing = Sky(nights: 30, newestIsNew: false).drawing
    let focus = SkyFocus()
    #expect(focus.figures(in: drawing).isEmpty)
    #expect(focus.lines(in: drawing).isEmpty)
    #expect(focus.names(in: drawing).isEmpty)
  }

  /// A tap on the open sky brightens every name and line; another fades them.
  @Test func openSkyTogglesEverything() {
    let drawing = Sky(nights: 30, newestIsNew: false).drawing
    var focus = SkyFocus()
    focus.tap(star: nil, in: drawing)
    #expect(focus.everything && focus.star == nil)
    #expect(focus.names(in: drawing) == [.bigDipper, .cassiopeia, .littleDipper, .orion])
    #expect(focus.lines(in: drawing) == Set(drawing.lines.indices))
    focus.tap(star: nil, in: drawing)
    #expect(focus == SkyFocus())
  }

  /// A star's night brings forward its own figure, lines and name, and nothing else.
  @Test func aStarBringsItsFigure() {
    let drawing = Sky(nights: 30, newestIsNew: false).drawing
    var focus = SkyFocus()
    focus.tap(star: 19, in: drawing)
    #expect(focus.star == 19 && !focus.everything)
    #expect(focus.names(in: drawing) == [.orion])
    let orion = Set(drawing.lines.indices.filter { drawing.lines[$0].constellation == .orion })
    #expect(!orion.isEmpty)
    #expect(focus.lines(in: drawing) == orion)
    focus.star = nil
    #expect(focus.figures(in: drawing).isEmpty)
  }

  /// With every name bright, a star's night keeps them all bright.
  @Test func aStarOverEverything() {
    let drawing = Sky(nights: 30, newestIsNew: false).drawing
    let focus = SkyFocus(everything: true, star: 3)
    #expect(focus.names(in: drawing).count == 4)
    #expect(focus.lines(in: drawing) == Set(drawing.lines.indices))
  }

  /// An incomplete figure has no name, so only its lit lines brighten.
  @Test func anIncompleteFigureHasOnlyLines() {
    let drawing = Sky(nights: 25, newestIsNew: false).drawing
    let focus = SkyFocus(star: 20)
    #expect(focus.names(in: drawing).isEmpty)
    let lines = focus.lines(in: drawing)
    #expect(!lines.isEmpty)
    #expect(lines.allSatisfy { drawing.lines[$0].constellation == .orion })
  }

  /// The empty sky has nothing to brighten: a tap does nothing.
  @Test func anEmptySkyStaysAsItIs() {
    let drawing = Sky(nights: 0, newestIsNew: false).drawing
    var focus = SkyFocus()
    focus.tap(star: nil, in: drawing)
    #expect(focus == SkyFocus())
    #expect(SkyFocus(star: 4).figures(in: drawing).isEmpty)
  }

  /// Past the table, a star still belongs to its figure.
  @Test func pastTheTable() {
    let drawing = Sky(nights: 180, newestIsNew: false).drawing
    #expect(SkyFocus(star: 0).names(in: drawing) == [.bigDipper])
  }
}
