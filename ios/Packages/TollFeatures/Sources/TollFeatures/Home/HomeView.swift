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
          NoteCard(Copy.Home.screenTimeOffCard) {
            Button(Copy.Home.turnOn, action: turnOnScreenTime)
              .tollType(.link, TollColor.accent)
              .frame(minHeight: 28)
          }
          .padding(.top, home.pill == nil ? 4 : 12)
        } else if home.locationBanner {
          NoteCard(locationFact) {
            Button(Copy.Home.fixInSettings, action: fixLocation)
              .tollType(.link, TollColor.accent)
              .frame(minHeight: 28)
          }
          .padding(.top, home.pill == nil ? 4 : 12)
        }
        HomeHero(hero: home.hero, openDoor: (home.unlocksLeft ?? 0) > 0 ? openDoor : nil)
          .padding(.top, heroGap)
        if case .paused = home.hero {
          PausedCard(price: price, open: openPurchase).padding(.top, 18)
        }
        if let timeline = home.timeline {
          TimelineStrip(timeline: timeline).padding(.top, home.locationBanner ? 20 : 16)
        }
        SectionHeader(
          home.weekTitle, action: openInsights.map { (title: Copy.Home.seeAll, run: $0) }
        )
        .padding(.top, 24)
        WeekCard(home: home).padding(.top, 16)
        SectionHeader(
          Copy.Home.blocks,
          action: openBlock.map { open in (title: Copy.Home.new, run: { open(nil) }) }
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
        Image(systemName: "gearshape").unredacted()
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

  var body: some View {
    if pill.opensPurchase {
      Button(action: open) {
        HStack(spacing: 6) {
          Text(pill.text)
          Image(systemName: "chevron.right").unredacted().font(.system(size: 10, weight: .bold))
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
        if pill.kind == .away {
          Image(systemName: "location").unredacted().font(.system(size: 12, weight: .medium))
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

/// The state, centred: an eyebrow, the big time (or "Not blocking"), one line, and "Open one app"
/// while blocked.
struct HomeHero: View {
  let hero: HomeSnapshot.Hero
  let openDoor: (() -> Void)?

  var body: some View {
    VStack(spacing: 6) {
      VStack(spacing: 6) {
        Text(eyebrow).tollType(.eyebrow, TollColor.label2)
        if let time {
          HeroTime(time)
        } else {
          Text(title)
            .tollType(TollType(size: 40, lineHeight: 46, weight: .semibold, style: .largeTitle))
            .foregroundStyle(TollColor.label)
        }
        Text(detail).tollType(.heroLine, TollColor.label2)
      }
      .multilineTextAlignment(.center)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
      if let openDoor {
        Button(Copy.Home.openOneApp, action: openDoor)
          .tollType(.link, TollColor.accent)
          .frame(minHeight: 32)
          .padding(.top, 4)
      }
    }
    .frame(maxWidth: .infinity)
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
