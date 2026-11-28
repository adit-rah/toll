import SwiftUI

/// What each of Tonight's parts is to `HomeLayout`.
enum HomeRole: Sendable {
  case bar, hero, note, strip
}

struct HomeRoleKey: LayoutValueKey {
  static let defaultValue = HomeRole.hero
}

/// A note that grows up from its row (last night's card) keeps to the strip: it is offered only the
/// room between the state and the strip, and scrolls its details inside it (#162), so opening it
/// never moves the band or the strip. Only when even its folded row can't fit there does it go
/// under the state, never under the bar.
struct HomeNoteKeepsToStripKey: LayoutValueKey {
  static let defaultValue = false
}

/// Tonight's composition below accessibility sizes (D64, D75): the bar at the top, the state a
/// little above centre and the strip at the bottom, laid out as if there were no card. A card or
/// note then floats in the room left over, so its coming and going never moves the state: first
/// just above the strip, then under the bar, and only when neither has room, after the state, where
/// the screen scrolls. A layout rather than measured state, so the first frame is already right.
struct HomeLayout: Layout {
  /// The screen's height less the margin under the strip; the base fills it.
  let height: CGFloat

  enum Band: Equatable {
    case bottom, top, flow
  }

  private enum Gap {
    /// The least room above and below the state, as the spacers had.
    static let aboveHero: CGFloat = 20
    static let belowHero: CGFloat = 28
    /// A card's room under the bar, from the state, and above the strip's own headroom.
    static let underBar: CGFloat = 4
    static let toHero: CGFloat = 20
    static let toStrip: CGFloat = 20
  }

  struct Arrangement {
    var y: [CGFloat] = []
    var heights: [CGFloat] = []
    var bands: [Band?] = []
    var total: CGFloat = 0
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width =
      proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
    return CGSize(width: width, height: arrange(width: width, subviews: subviews).total)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let arrangement = arrange(width: bounds.width, subviews: subviews)
    for (index, subview) in subviews.enumerated() {
      subview.place(
        at: CGPoint(x: bounds.minX, y: bounds.minY + arrangement.y[index]), anchor: .topLeading,
        proposal: ProposedViewSize(width: bounds.width, height: arrangement.heights[index]))
    }
  }

  func arrange(width: CGFloat, subviews: Subviews) -> Arrangement {
    let fit = ProposedViewSize(width: width, height: nil)
    let roles = subviews.map { $0[HomeRoleKey.self] }
    var result = Arrangement(heights: subviews.map { $0.sizeThatFits(fit).height })
    let heights = result.heights
    func tallest(_ role: HomeRole) -> CGFloat {
      zip(roles, heights).filter { $0.0 == role }.map(\.1).max() ?? 0
    }
    let bar = tallest(.bar)
    let hero = tallest(.hero)
    let strip = tallest(.strip)
    // Twice the room below the state as above it, as the spacers gave: a little above centre.
    let free = self.height - bar - hero - strip
    let heroY = bar + max(Gap.aboveHero, min(free / 3, free - Gap.belowHero))
    let heroBottom = heroY + hero
    let baseStripY = max(self.height - strip, heroBottom + Gap.belowHero)
    var stripY = baseStripY

    for (index, role) in roles.enumerated() {
      guard role == .note else {
        result.bands.append(nil)
        continue
      }
      let keepsToStrip = subviews[index][HomeNoteKeepsToStripKey.self]
      let room = baseStripY - Gap.toStrip - heroBottom - Gap.toHero
      if keepsToStrip, room > 0 {
        let capped = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: room))
        if capped.height <= room {
          result.heights[index] = capped.height
          result.bands.append(.bottom)
          continue
        }
      }
      let note = result.heights[index]
      let band = Self.band(
        note: note, barBottom: bar, heroTop: heroY, heroBottom: heroBottom, stripTop: baseStripY,
        underBar: !keepsToStrip)
      result.bands.append(band)
      if band == .flow {
        stripY = max(stripY, heroBottom + Gap.toHero + note + Gap.belowHero)
      }
    }

    for (index, role) in roles.enumerated() {
      let y: CGFloat =
        switch (role, result.bands[index]) {
        case (.bar, _): 0
        case (.hero, _): heroY
        case (.strip, _): stripY
        case (.note, .bottom?): baseStripY - Gap.toStrip - result.heights[index]
        case (.note, .top?): bar + Gap.underBar
        case (.note, _): heroBottom + Gap.toHero
        }
      result.y.append(y)
    }
    result.total = max(self.height, stripY + strip)
    return result
  }

  /// Just above the strip if it fits there, else under the bar, else after the state. A card that
  /// would touch the state or the strip never floats.
  static func band(
    note: CGFloat, barBottom: CGFloat, heroTop: CGFloat, heroBottom: CGFloat, stripTop: CGFloat,
    underBar: Bool = true
  ) -> Band {
    if stripTop - Gap.toStrip - note >= heroBottom + Gap.toHero { return .bottom }
    if underBar, barBottom + Gap.underBar + note + Gap.toHero <= heroTop { return .top }
    return .flow
  }
}
