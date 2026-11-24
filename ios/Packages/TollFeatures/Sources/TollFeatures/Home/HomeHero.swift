import SwiftUI
import TollCore
import TollUI

/// The state, centred (#72, rule 2): its glyph and an eyebrow that says what the big time means
/// ("Apps lock at", "Apps locked until", D75), the big time (or the state's glyph when nothing will
/// block), one line, the week's pauses as dots while locked, and "Pause" or "Lock again" as buttons.
struct HomeHero: View {
  let hero: HomeSnapshot.Hero
  let eyebrow: String
  var place: HomeSnapshot.HeroPlace?
  var supply: HomeSnapshot.Supply?
  let openDoor: (() -> Void)?
  /// While a pause is open: lock now, as the pause sheet's button does.
  var lockAgain: (() -> Void)?
  /// With no night: its editor ("Set your night").
  var setNight: (() -> Void)?
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    VStack(spacing: 6) {
      VStack(spacing: 6) {
        StateLine(eyebrow, symbol: state.symbol, tone: state.tone)
        if let time {
          HeroTime(time)
        } else if let off = offSymbol {
          // Nothing will block: the biggest shape on screen says so, not two words (#72). No tile
          // behind it: a filled square reads as a button, and this isn't one (the audit).
          Image(symbol: off).unredacted()
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(TollColor.label2)
            .frame(width: 64, height: 64)
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
      if case .noBlocks = hero, let setNight {
        PrimaryButton(Copy.Home.setNight, action: setNight).padding(.top, 18)
      }
    }
    .frame(maxWidth: .infinity)
  }

  /// The pause is the escape hatch: findable, not inviting (D61, D67). The week's pauses as dots with
  /// their count and week beside them, and a small grey capsule, not an amber button across the
  /// screen: "Pause" while locked, "Lock again" while a pause is open.
  private func pauses(_ supply: HomeSnapshot.Supply) -> some View {
    // Side by side; stacked at larger sizes so the capsule never squeezes.
    let layout =
      typeSize > .large
      ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 14))
    return layout {
      HStack(spacing: 8) {
        Pips(
          filled: supply.left, total: supply.max,
          spoken: Copy.Door.pausesLeft(supply.left, of: supply.max))
        // The dots already say it to VoiceOver.
        Text(Copy.Door.pausesOf(supply.left, supply.max))
          .tollType(.detail, TollColor.label2)
          .accessibilityHidden(true)
      }
      if case .blocked = hero, let openDoor {
        capsule(Copy.Home.pause, symbol: .unlock, action: openDoor)
          .accessibilityLabel(Copy.Home.pauseSpoken)
      }
      if case .paused = hero, let lockAgain {
        capsule(Copy.Home.lockAgain, symbol: .blocked, action: lockAgain)
      }
    }
    .padding(.top, 2)
  }

  private func capsule(_ title: String, symbol: TollSymbol, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(symbol: symbol).unredacted()
          .font(.system(size: 13, weight: .semibold))
          .accessibilityHidden(true)
        Text(title)
      }
      .tollType(.smallQuiet, TollColor.label2)
      .padding(.horizontal, 12)
      .frame(minHeight: 32)
      .background(TollColor.surfaceRaised, in: Capsule())
      .frame(minHeight: TollSpacing.minTapTarget)
      .contentShape(Rectangle())
    }
    .buttonStyle(.tollPressable)
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
  /// home, since the line then says "You're home". Away is already said by the glyph.
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
