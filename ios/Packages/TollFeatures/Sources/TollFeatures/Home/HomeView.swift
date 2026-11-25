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
  /// While a pause is open, from the hero (the pause sheet can be swiped away).
  var lockAgain: () -> Void = {}
  let openPurchase: () -> Void
  let fixLocation: () -> Void
  var turnOnScreenTime: () -> Void = {}
  /// The Tonight card's link and its "Not now" (#102).
  var openCard: (TonightCard) -> Void = { _ in }
  var dismissCard: (TonightCard) -> Void = { _ in }
  /// Before bed's helpers, from the capsule in the gap (D80).
  var openHelpers: () -> Void = {}
  /// Last night's card's "OK": put away for this morning, by the night's key.
  var putAwayLastNight: (Date) -> Void = { _ in }
  /// A block's editor, from the strip's snippet (D75).
  var openBlock: (BlockID) -> Void = { _ in }
  /// Demo renders open the strip on this segment's snippet: a block, or "lastNight" (docs/renders.md).
  var snippet: String?
  @Environment(\.dynamicTypeSize) private var typeSize

  private static let bottomMargin: CGFloat = 28

  /// A composition, not a list (D64): the bar with the pill in it, the state just above the middle
  /// where the eye lands, and the day's strip at the bottom like a horizon (D75). A card or note
  /// floats in the room left over and never moves the state (`HomeLayout`). At accessibility sizes
  /// the screen is one column that scrolls, the state before the pill and any card, so a card can't
  /// push it off the screen (the audit). Either way VoiceOver reads the state before the card.
  var body: some View {
    GeometryReader { proxy in
      ScrollView {
        Group {
          if typeSize.isAccessibilitySize {
            stacked
          } else {
            floating(height: proxy.size.height - Self.bottomMargin)
          }
        }
        .tollGutter()
        .padding(.bottom, Self.bottomMargin)
        .frame(minHeight: proxy.size.height)
      }
    }
    .background(TollColor.bg)
    .animation(Motion.stateChange, value: home.hero)
    // Design §2.5: a card fades in place; nothing else moves.
    .animation(Motion.stateChange, value: note)
  }

  /// Below accessibility sizes. The sort priorities read the bar, the state, the card, the strip.
  private func floating(height: CGFloat) -> some View {
    HomeLayout(height: height) {
      topBar(withPill: true)
        .accessibilityElement(children: .contain)
        .layoutValue(key: HomeRoleKey.self, value: .bar)
        .accessibilitySortPriority(3)
      heroBlock
        .layoutValue(key: HomeRoleKey.self, value: .hero)
        .accessibilitySortPriority(2)
      if let note {
        noteView(note)
          .accessibilityElement(children: .contain)
          .layoutValue(key: HomeRoleKey.self, value: .note)
          .accessibilitySortPriority(1)
          .transition(.opacity)
          .id(note)
      }
      strip.layoutValue(key: HomeRoleKey.self, value: .strip)
    }
    .accessibilityElement(children: .contain)
  }

  /// Accessibility sizes: the state, then the pill and any card, then the strip.
  private var stacked: some View {
    VStack(alignment: .leading, spacing: 0) {
      topBar(withPill: false)
      Spacer(minLength: 20)
      VStack(spacing: 0) {
        heroBlock
        status.padding(.top, 20)
      }
      // Twice the room below as above: the state sits a little above centre.
      Spacer(minLength: 28)
      Spacer(minLength: 0)
      strip
    }
  }

  /// The state, and what belongs with it: the purchase card once Off, the line about another block.
  private var heroBlock: some View {
    VStack(spacing: 0) {
      // Tonight's state all day; last night is a card to review, never the hero (founder, 25 Nov).
      HomeHero(
        hero: home.hero, eyebrow: home.eyebrow, beforeBed: home.beforeBed,
        place: home.heroPlace, supply: home.supply,
        openDoor: (home.unlocksLeft ?? 0) > 0 ? openDoor : nil, lockAgain: lockAgain,
        setNight: home.setNight.map { night -> () -> Void in { openBlock(night) } },
        openHelpers: home.untilBed == nil ? nil : openHelpers
      )
      if case .off = home.hero {
        OffCard(price: price, open: openPurchase).padding(.top, 18)
      }
      if let other = home.otherBlock {
        OtherBlockLine(line: other, openDoor: openDoor).padding(.top, 14)
      }
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder private var strip: some View {
    if let timeline = home.timeline {
      DayStrip(timeline: timeline, openBlock: openBlock, initial: snippet)
    }
  }

  /// One at a time, the most pressing first: Screen Time off, then location, then last night's
  /// card in the morning, then Tonight's offers.
  private var note: HomeNote? {
    if home.screenTimeOff { return .screenTimeOff }
    if home.locationBanner { return .location }
    if home.lastNightCard, home.lastNight != nil { return .lastNight }
    return home.card.map(HomeNote.card)
  }

  /// At accessibility sizes, the free-night pill and a card, both when both apply: without Always
  /// the card used to hide the last free night (#45). The card sits 12 pt under the pill.
  @ViewBuilder private var status: some View {
    if let pill = home.pill {
      PillView(pill: pill, open: openPurchase)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
    if let note {
      noteView(note).padding(.top, home.pill == nil ? 4 : 12)
    }
  }

  @ViewBuilder private func noteView(_ note: HomeNote) -> some View {
    switch note {
    case .screenTimeOff:
      NoteCard(Copy.Home.screenTimeOffCard, severity: .broken) {
        SettingsLink(Copy.Home.turnOn, action: turnOnScreenTime)
      }
    case .location:
      NoteCard(locationFact, severity: .degraded) {
        SettingsLink(Copy.Home.fixInSettings, action: fixLocation)
      }
    case .lastNight:
      if let night = home.lastNight {
        LastNightCard(night: night) { putAwayLastNight(night.night) }
      }
    case .card(let card):
      TonightCardView(
        card: card, headsUp: home.headsUp, gap: home.gapCard, untilBed: home.untilBed,
        open: { openCard(card) },
        dismiss: { dismissCard(card) }
      )
    }
  }

  /// The gear, and the pill centred in the bar, so its coming and going moves nothing; it drops its
  /// segments before it would crowd the gear. At accessibility sizes it's under the state instead.
  private func topBar(withPill: Bool) -> some View {
    ZStack {
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
      if withPill, let pill = home.pill {
        ViewThatFits(in: .horizontal) {
          PillView(pill: pill, open: openPurchase)
          PillView(pill: pill, segments: false, open: openPurchase)
        }
        .padding(.horizontal, TollSpacing.minTapTarget)
      }
    }
    .frame(height: TollSpacing.barHeight)
  }
}

/// What may float over Tonight, one at a time.
enum HomeNote: Hashable {
  case screenTimeOff, location, lastNight
  case card(TonightCard)
}
