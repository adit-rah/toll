import SwiftUI
import TollCore
import TollData
import TollUI

/// Home, in every state (the design canvas's Home row): the bar, a quiet pill, what tonight holds,
/// the strip, the week and the blocks, at the boards' gaps. Laid out from a `HomeSnapshot`; nothing
/// here decides anything.
struct HomeView: View {
  let home: HomeSnapshot
  let price: String
  var locationFact = Copy.Setup.whileUsingFact
  let openSettings: () -> Void
  let openDoor: () -> Void
  let openPurchase: () -> Void
  let fixLocation: () -> Void
  var openBlock: ((BlockID?) -> Void)?
  var openInsights: (() -> Void)?
  var turnOnScreenTime: () -> Void = {}

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        topBar
        // The pill and a card both show: without Always, the card used to hide the last free
        // night (#45). The card sits 12 pt under the pill.
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
        }
        HomeHero(
          hero: home.hero, place: home.heroPlace, supply: home.supply,
          openDoor: (home.unlocksLeft ?? 0) > 0 ? openDoor : nil
        )
        .padding(.top, heroGap)
        if case .paused = home.hero {
          PausedCard(price: price, open: openPurchase).padding(.top, 18)
        }
        if let timeline = home.timeline {
          TimelineStrip(timeline: timeline).padding(.top, home.locationBanner ? 20 : 16)
        }
        SectionHeader(
          home.weekTitle,
          action: openInsights.map { .init(Copy.Home.seeAll, symbol: .forward, run: $0) }
        )
        .padding(.top, 24)
        WeekCard(home: home).padding(.top, 16)
        SectionHeader(
          Copy.Home.blocks,
          action: openBlock.map { open in .init(Copy.Home.new, symbol: .add) { open(nil) } }
        )
        .padding(.top, 22)
        BlockList(
          rows: home.blocks, open: openBlock.map { open in { (id: BlockID) in open(id) } }
        )
        .padding(.top, TollSpacing.headerToCard)
      }
      .tollGutter()
      .padding(.bottom, 32)
    }
    .background(TollColor.bg)
    .animation(Motion.stateChange, value: home.hero)
  }

  /// The boards: 16 pt under the pill or the bar, 14 above "Paused", 20 under the location card.
  private var heroGap: CGFloat {
    if home.locationBanner || home.screenTimeOff { return 20 }
    if case .paused = home.hero { return 14 }
    return 16
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

/// The pill under the bar: grey on `surface` for a free night and for "Away from home"; the last
/// free night in amber on its tint, and only that one opens anything (D33).
private struct PillView: View {
  let pill: HomeSnapshot.Pill
  let open: () -> Void

  /// The free week as seven segments, the nights already ended filled (#77): night 2 and night 6
  /// look different without the words.
  @ViewBuilder private var segments: some View {
    if let night = pill.night {
      Pips(
        filled: night - 1, total: pill.nights, style: .segments, spoken: pill.text
      )
      .accessibilityHidden(true)
    }
  }

  var body: some View {
    if pill.opensPurchase {
      Button(action: open) {
        HStack(spacing: 6) {
          segments
          Text(pill.text)
          Image(symbol: .forward).unredacted().font(.system(size: 10, weight: .bold))
        }
        .tollType(.trailing, TollColor.accent)
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .frame(minHeight: 30)
        .background(TollColor.accentSoft, in: Capsule())
        .frame(minHeight: TollSpacing.minTapTarget)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .padding(.vertical, -7)
    } else {
      HStack(spacing: 6) {
        segments
        if pill.kind == .away {
          Image(symbol: .away).unredacted().font(.system(size: 12, weight: .medium))
        }
        Text(pill.text)
      }
      .tollType(TollType(size: 13, lineHeight: 18, weight: .medium, style: .footnote))
      .foregroundStyle(TollColor.label2)
      .padding(.horizontal, 14)
      .frame(minHeight: 30)
      .background(TollColor.surface, in: Capsule())
      .accessibilityElement(children: .combine)
    }
  }
}

/// The state, centred (#72, rule 2): its glyph and eyebrow, the big time (or the state's glyph
/// when nothing will block), one line led by where it runs, the unlocks as dots while blocked, and
/// "Open one app" as a button.
struct HomeHero: View {
  let hero: HomeSnapshot.Hero
  var place: HomeSnapshot.HeroPlace?
  var supply: HomeSnapshot.Supply?
  let openDoor: (() -> Void)?

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
      // The door is the escape hatch: findable, not inviting (D61). A small grey capsule beside the
      // unlocks, not an amber button across the screen.
      if case .blocked = hero, let supply {
        HStack(spacing: 14) {
          Pips(
            filled: supply.left, total: supply.max,
            spoken: Copy.Door.unlocksLeft(supply.left, of: supply.max))
          if let openDoor {
            Button(action: openDoor) {
              HStack(spacing: 6) {
                Image(symbol: .unlock).unredacted()
                  .font(.system(size: 13, weight: .semibold))
                  .accessibilityHidden(true)
                Text(Copy.Home.openOneApp)
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

/// What Settings' location says, as one fact (D37).
func locationFact(_ state: LocationAccess.State) -> String {
  switch state {
  case .approximate: Copy.Setup.approximateFact
  case .denied, .notDetermined: Copy.Setup.deniedFact
  case .whileUsing, .always: Copy.Setup.whileUsingFact
  }
}
