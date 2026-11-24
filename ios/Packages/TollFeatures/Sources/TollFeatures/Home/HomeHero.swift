import SwiftUI
import TollCore
import TollUI

/// The state, centred (#72, rule 2): its glyph and an eyebrow that says what the big time means
/// ("Apps lock at", "Apps locked until", D75), the big time (or the state's glyph when nothing will
/// block), one line, the week's pauses as dots while locked, and "Pause" as a button.
struct HomeHero: View {
  let hero: HomeSnapshot.Hero
  let eyebrow: String
  var place: HomeSnapshot.HeroPlace?
  var supply: HomeSnapshot.Supply?
  let openDoor: (() -> Void)?
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    VStack(spacing: 6) {
      VStack(spacing: 6) {
        StateLine(eyebrow, symbol: state.symbol, tone: state.tone)
        if let time {
          HeroTime(time)
        } else if let off = offSymbol {
          // Nothing will block: the biggest shape on screen says so, not two words (#72).
          Image(symbol: off).unredacted()
            .font(.system(size: 30, weight: .medium))
            .foregroundStyle(TollColor.label2)
            .frame(width: 64, height: 64)
            .background(
              TollColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .padding(.vertical, 6)
            .accessibilityLabel(Copy.Home.notBlocking)
        } else {
          Text(Copy.Home.noBlocks)
            .tollType(TollType(size: 40, lineHeight: 46, weight: .semibold, style: .largeTitle))
            .foregroundStyle(TollColor.label)
        }
        if !detail.isEmpty {
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let placeSymbol {
              Image(symbol: placeSymbol).unredacted()
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TollColor.label2)
                .accessibilityHidden(true)
            }
            Text(detail).tollType(.heroLine, TollColor.label2)
          }
        }
      }
      .multilineTextAlignment(.center)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
      if showsPauses, let supply {
        pauses(supply)
      }
    }
    .frame(maxWidth: .infinity)
  }

  /// The pause is the escape hatch: findable, not inviting (D61, D67). A small grey capsule beside
  /// the week's pauses, not an amber button across the screen; none while one is already open.
  private func pauses(_ supply: HomeSnapshot.Supply) -> some View {
    // Side by side; stacked at accessibility sizes so the capsule never squeezes.
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 14))
    return layout {
      Pips(
        filled: supply.left, total: supply.max,
        spoken: Copy.Door.pausesLeft(supply.left, of: supply.max))
      if case .blocked = hero, let openDoor {
        Button(action: openDoor) {
          HStack(spacing: 6) {
            Image(symbol: .unlock).unredacted()
              .font(.system(size: 13, weight: .semibold))
              .accessibilityHidden(true)
            Text(Copy.Home.pause)
          }
          .tollType(.smallQuiet, TollColor.label2)
          .padding(.horizontal, 12)
          .frame(minHeight: 32)
          .background(TollColor.surfaceRaised, in: Capsule())
          .frame(minHeight: TollSpacing.minTapTarget)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.top, 2)
  }

  private var showsPauses: Bool {
    switch hero {
    case .blocked, .paused: true
    default: false
    }
  }

  private var state: (symbol: TollSymbol, tone: StateLine.Tone) {
    switch hero {
    case .tonight: (.later, .neutral)
    case .blocked: (.blocked, .accent)
    case .paused: (.unlock, .neutral)
    case .away: (.away, .neutral)
    case .off: (.off, .neutral)
    case .screenTimeOff: (.broken, .warn)
    case .noBlocks: (.sleep, .neutral)
    }
  }

  private var offSymbol: TollSymbol? {
    switch hero {
    case .off: .off
    case .screenTimeOff: .broken
    default: nil
    }
  }

  /// Where the night runs, before the line: home or anywhere before it starts; while locked, only
  /// home, since the line then says "You're home". Away is already said by the pill and the glyph.
  private var placeSymbol: TollSymbol? {
    switch hero {
    case .tonight: place.map { $0 == .home ? .home : .anywhere }
    case .blocked: place == .home ? .home : nil
    default: nil
    }
  }

  private var time: Date? {
    switch hero {
    case .tonight(let start, _): start
    case .blocked(let until, _): until
    case .paused(let until, _): until
    case .away(let end): end
    case .off, .screenTimeOff, .noBlocks: nil
    }
  }

  private var detail: String {
    switch hero {
    case .tonight(_, let detail), .blocked(_, let detail): detail
    case .paused(_, let nightEnd): Copy.Home.thenLockedUntil(Copy.time(nightEnd))
    case .away: Copy.Home.locksWhenHome
    case .off(let today): today ? Copy.Home.trialEndedToday : Copy.Home.trialEnded
    case .screenTimeOff: Copy.Home.screenTimeOffDetail
    case .noBlocks: ""
    }
  }
}
