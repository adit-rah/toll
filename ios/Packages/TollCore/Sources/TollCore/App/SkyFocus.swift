/// Which of Your sky's figures stand out. The names and lines stay faint, so the sky reads as a sky;
/// a curious tap brings them forward. A tap on the open sky brightens every one and another fades
/// them; while a star's night is open, its own figure is bright. Nothing dims them on its own, and
/// nothing is kept: Your sleep starts faint each time it appears.
public struct SkyFocus: Equatable, Sendable {
  /// Every name and line brightened, by a tap on the open sky.
  public var everything: Bool
  /// The lit star whose night is open, as an index into `Sky.Drawing.stars`.
  public var star: Int?

  public init(everything: Bool = false, star: Int? = nil) {
    self.everything = everything
    self.star = star
  }

  /// A tap on the sky. `star` is the lit star it landed near (`SkyLayout.nearest`), whose night
  /// opens; nil is the open sky, which brightens or fades every name. An empty sky has none.
  public mutating func tap(star: Int?, in drawing: Sky.Drawing) {
    if let star {
      self.star = star
    } else if !drawing.stars.isEmpty {
      everything.toggle()
    }
  }

  /// The figures drawn bright: every one with a line or a name, or the open star's own.
  public func figures(in drawing: Sky.Drawing) -> Set<Constellation> {
    var figures = Set<Constellation>()
    if everything {
      figures.formUnion(drawing.lines.map(\.constellation))
      figures.formUnion(drawing.names.map(\.constellation))
    }
    if let star, drawing.stars.indices.contains(star) {
      figures.insert(drawing.stars[star].constellation)
    }
    return figures
  }

  /// The lines drawn bright, as indexes into `Sky.Drawing.lines`.
  public func lines(in drawing: Sky.Drawing) -> Set<Int> {
    let figures = figures(in: drawing)
    return Set(drawing.lines.indices.filter { figures.contains(drawing.lines[$0].constellation) })
  }

  /// The names drawn bright. An incomplete figure has no name, so only its lines brighten.
  public func names(in drawing: Sky.Drawing) -> Set<Constellation> {
    let figures = figures(in: drawing)
    return Set(drawing.names.map(\.constellation).filter(figures.contains))
  }
}
