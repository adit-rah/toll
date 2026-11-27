import SwiftUI
import TollCore
import TollUI

/// The state, centred (#72, rule 2): its glyph over an eyebrow that says what the big time means
/// ("Apps lock at", "Apps locked until", D75), the big time, one line, the week's pauses as dots
/// while locked, and "Pause" or "Lock again" as buttons. The glyph is big enough to tell the states
/// apart with every word wiped (#74); when nothing will block it stands in for the time.
struct HomeHero: View {
  let hero: HomeSnapshot.Hero
  let eyebrow: String
  /// "15 min before bed", under the lock's time (D76).
  var beforeBed: String?
  var place: HomeSnapshot.HeroPlace?
  var supply: HomeSnapshot.Supply?
  let openDoor: (() -> Void)?
  /// While a pause is open: lock now, as the pause sheet's button does.
  var lockAgain: (() -> Void)?
  /// With no night: its editor ("Set your night").
  var setNight: (() -> Void)?
  /// In the gap before bed: the helpers' sheet (D80).
  var openHelpers: (() -> Void)?
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    VStack(spacing: 6) {
      VStack(spacing: 6) {
        // Nothing will block: the mark stands in for the time and says so to VoiceOver.
        StateMark(
          state.symbol, tone: state.tone, large: offSymbol != nil,
          spoken: offSymbol == nil ? nil : Copy.Home.notBlocking)
        Text(eyebrow).tollType(.eyebrow, TollColor.label2)
        if let time {
          HeroTime(time)
          if let beforeBed {
            // The moon says before what, without the words (D76).
            HStack(alignment: .firstTextBaseline, spacing: 6) {
              Image(symbol: .sleep).unredacted()
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TollColor.accent)
                .accessibilityHidden(true)
              Text(beforeBed).tollType(.heroLine, TollColor.label)
            }
          }
        } else if offSymbol == nil {
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
      // Under the pauses, the same quiet shape: findable, not inviting (D61, D80).
      if let openHelpers {
        capsule(Copy.Helpers.capsule, symbol: .beforeBed, action: openHelpers)
          .accessibilityHint(Copy.Helpers.capsuleHint)
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

  /// The line's glyph. Where the night runs: home or anywhere before it starts; while locked, only
  /// home, since the line then says "You're home"; away, the home it waits for ("Apps lock when
  /// you're home", #74). While paused, the lock that comes back ("Then locked until 7:00 am").
  private var placeSymbol: TollSymbol? {
    switch hero {
    case .tonight: place.map { $0 == .home ? .home : .anywhere }
    case .blocked: place == .home ? .home : nil
    case .away: .home
    case .paused: .blocked
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
