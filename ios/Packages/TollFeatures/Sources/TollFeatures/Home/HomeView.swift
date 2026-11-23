import SwiftUI
import TollCore
import TollData
import TollUI

/// Tonight, the first tab (D63): the bar, a quiet pill, what tonight holds and the strip, at the
/// boards' gaps. The week is on Your sleep and the blocks on Blocks. Laid out from a `HomeSnapshot`; nothing
/// here decides anything.
struct HomeView: View {
  let home: HomeSnapshot
  let price: String
  var locationFact = Copy.Setup.whileUsingFact
  let openSettings: () -> Void
  let openDoor: () -> Void
  let openPurchase: () -> Void
  let fixLocation: () -> Void
  var turnOnScreenTime: () -> Void = {}
  /// The Tonight card's link and its "Not now" (#102).
  var openCard: (TonightCard) -> Void = { _ in }
  var dismissCard: (TonightCard) -> Void = { _ in }

  /// A composition, not a list (D64): what needs attention at the top, the state just above the
  /// middle where the eye lands, and the day strip at the bottom like a horizon. At accessibility
  /// sizes the spacers collapse and the screen scrolls.
  var body: some View {
    GeometryReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          topBar
          status
          Spacer(minLength: 20)
          VStack(spacing: 0) {
            // From the end of the night until noon, last night takes the hero's place (#103).
            if let morning = home.morning {
              MorningCard(morning: morning, nights: home.bars)
            } else {
              HomeHero(
                hero: home.hero, place: home.heroPlace, supply: home.supply,
                phoneFree: home.phoneFree, openDoor: (home.unlocksLeft ?? 0) > 0 ? openDoor : nil
              )
            }
            if case .paused = home.hero {
              PausedCard(price: price, open: openPurchase).padding(.top, 18)
            }
            if let other = home.otherBlock {
              OtherBlockLine(line: other, openDoor: openDoor).padding(.top, 14)
            }
          }
          // Twice the room below as above: the state sits a little above centre.
          Spacer(minLength: 28)
          Spacer(minLength: 0)
          if let timeline = home.timeline {
            TimelineStrip(timeline: timeline)
          }
        }
        .tollGutter()
        .padding(.bottom, 28)
        .frame(minHeight: proxy.size.height)
      }
    }
    .background(TollColor.bg)
    .animation(Motion.stateChange, value: home.hero)
    .animation(Motion.stateChange, value: home.morning)
  }

  /// The free-night pill and a card, both when both apply: without Always the card used to hide
  /// the last free night (#45). The card sits 12 pt under the pill.
  @ViewBuilder private var status: some View {
    if let pill = home.pill {
      PillView(pill: pill, open: openPurchase)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
    if home.screenTimeOff {
      NoteCard(Copy.Home.screenTimeOffCard, severity: .broken) {
        SettingsLink(Copy.Home.turnOn, action: turnOnScreenTime)
      }
      .padding(.top, home.pill == nil ? 4 : 12)
    } else if home.locationBanner {
      NoteCard(locationFact, severity: .degraded) {
        SettingsLink(Copy.Home.fixInSettings, action: fixLocation)
      }
      .padding(.top, home.pill == nil ? 4 : 12)
    } else if let card = home.card {
      TonightCardView(
        card: card, headsUp: home.headsUp, open: { openCard(card) }, dismiss: { dismissCard(card) }
      )
      .padding(.top, home.pill == nil ? 4 : 12)
    }
  }

  private var topBar: some View {
    HStack {
      Spacer()
      Button(action: openSettings) {
        Image(symbol: .settings).unredacted()
          .font(.system(size: 20, weight: .regular))
          .foregroundStyle(TollColor.label2)
          .frame(width: TollSpacing.minTapTarget, height: TollSpacing.minTapTarget)
      }
      .accessibilityLabel(Copy.Home.settings)
      .padding(.trailing, -10)
    }
    .frame(height: TollSpacing.barHeight)
  }
}

/// The state, centred (#72, rule 2): its glyph and eyebrow, the big time (or the state's glyph
/// when nothing will block), one line led by where it runs, the week's pauses as dots while blocked,
/// and "Pause" as a button.
struct HomeHero: View {
  let hero: HomeSnapshot.Hero
  var place: HomeSnapshot.HeroPlace?
  var supply: HomeSnapshot.Supply?
  /// "8 h 30 m phone-free tonight", under the start time (#103).
  var phoneFree: String?
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
            .accessibilityLabel(title)
        } else {
          Text(title)
            .tollType(TollType(size: 40, lineHeight: 46, weight: .semibold, style: .largeTitle))
            .foregroundStyle(TollColor.label)
        }
        if let phoneFree { PhoneFreeLine(text: phoneFree) }
        HStack(spacing: 6) {
          if let placeSymbol {
            Image(symbol: placeSymbol).unredacted()
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(TollColor.label2)
              .accessibilityHidden(true)
          }
          Text(detail).tollType(.heroLine, TollColor.label2)
        }
      }
      .multilineTextAlignment(.center)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
      // The pause is the escape hatch: findable, not inviting (D61, D67). A small grey capsule
      // beside the week's pauses, not an amber button across the screen.
      if case .blocked = hero, let supply {
        // Side by side; stacked at accessibility sizes so the capsule never squeezes.
        let layout =
          typeSize.isAccessibilitySize
          ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 14))
        layout {
          Pips(
            filled: supply.left, total: supply.max,
            spoken: Copy.Door.pausesLeft(supply.left, of: supply.max))
          if let openDoor {
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
    }
    .frame(maxWidth: .infinity)
  }

  private var state: (symbol: TollSymbol, tone: StateLine.Tone) {
    switch hero {
    case .tonight: (.later, .neutral)
    case .blocked: (.blocked, .accent)
    case .away: (.away, .neutral)
    case .paused: (.paused, .neutral)
    case .screenTimeOff: (.broken, .warn)
    case .noBlocks: (.sleep, .neutral)
    }
  }

  private var offSymbol: TollSymbol? {
    switch hero {
    case .paused: .paused
    case .screenTimeOff: .broken
    default: nil
    }
  }

  private var placeSymbol: TollSymbol? {
    switch hero {
    case .tonight: place.map { $0 == .home ? .home : .anywhere }
    // Sleep's place; another block's line names its own.
    case .blocked(let label, _, _) where label == Copy.Home.blockedUntil:
      place.map { $0 == .home ? .home : .anywhere }
    // Away is already said by the pill and the state line.
    default: nil
    }
  }

  private var eyebrow: String {
    switch hero {
    case .tonight, .away: Copy.Home.tonight
    case .blocked(let label, _, _): label
    case .paused: Copy.Home.paused
    case .screenTimeOff: Copy.Home.screenTimeOffEyebrow
    case .noBlocks: ""
    }
  }

  private var time: Date? {
    switch hero {
    case .tonight(let start, _): start
    case .blocked(_, let until, _): until
    case .away(let start): start
    case .paused, .screenTimeOff, .noBlocks: nil
    }
  }

  private var title: String {
    switch hero {
    case .paused, .screenTimeOff: return Copy.Home.notBlocking
    default: return Copy.Home.noBlocks
    }
  }

  private var detail: String {
    switch hero {
    case .tonight(_, let detail), .blocked(_, _, let detail): detail
    case .away: Copy.Home.startsWhenHome
    case .paused(let today): today ? Copy.Home.trialEndedToday : Copy.Home.trialEnded
    case .screenTimeOff: Copy.Home.screenTimeOffDetail
    case .noBlocks: ""
    }
  }
}
