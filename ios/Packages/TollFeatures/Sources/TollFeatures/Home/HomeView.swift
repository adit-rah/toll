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
  /// The night came back without its apps (#140): Apple's picker over the night's editor.
  var chooseNightApps: () -> Void = {}
  /// The Tonight card's link and its "Not now" (#102).
  var openCard: (TonightCard) -> Void = { _ in }
  var dismissCard: (TonightCard) -> Void = { _ in }
  /// Before bed's helpers, from the capsule in the gap (D80).
  var openHelpers: () -> Void = {}
  /// Last night's card's "OK": put away for this morning, by the night's key.
  var putAwayLastNight: (Date) -> Void = { _ in }
  /// A block's editor, from the strip's snippet (D75).
  var openBlock: (BlockID) -> Void = { _ in }
  /// The one-time flow's card in the band (D92): its action, "Not now", and that it was seen.
  var openFlow: () -> Void = {}
  var notNowFlow: () -> Void = {}
  var flowShown: () -> Void = {}
  /// Demo renders open the strip on this segment's snippet: a block, or "lastNight" (docs/renders.md).
  var snippet: String?
  /// Demo renders open last night's card in the band.
  var lastNightStartsOpen = false
  /// Last night's card in the band, open or folded to its row. Never kept: folded each time Tonight
  /// appears.
  @State private var lastNightOpen = false
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.scenePhase) private var scenePhase

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
    .onAppear { lastNightOpen = lastNightStartsOpen }
    .onDisappear { lastNightOpen = false }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background { lastNightOpen = false }
    }
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
      if !home.band.isEmpty {
        band
          .layoutValue(key: HomeRoleKey.self, value: .note)
          .layoutValue(key: HomeNoteKeepsToStripKey.self, value: home.band.hasLastNight)
          .accessibilitySortPriority(1)
          .transition(.opacity.animation(Motion.stateChange))
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
    // Design §2.5: the state line crossfades. Scoped to the state, so a change in the band never
    // animates it (D86).
    .animation(Motion.stateChange, value: home.hero)
  }

  @ViewBuilder private var strip: some View {
    if let timeline = home.timeline {
      DayStrip(timeline: timeline, openBlock: openBlock, initial: snippet)
    }
  }

  /// At accessibility sizes, the free-night pill and the band, both when both apply: without
  /// Always the card used to hide the last free night (#45). The band sits 12 pt under the pill.
  @ViewBuilder private var status: some View {
    if let pill = home.pill {
      PillView(pill: pill, open: openPurchase)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
    if !home.band.isEmpty {
      band.padding(.top, home.pill == nil ? 4 : 12)
        .transition(.opacity.animation(Motion.stateChange))
    }
  }

  /// Tonight's band (`TonightBand`): one card, and last night's row under it.
  private var band: some View {
    TonightBandView(
      home: home, locationFact: locationFact, lastNightOpen: $lastNightOpen,
      growsUp: !typeSize.isAccessibilitySize,
      actions: TonightBandActions(
        fixLocation: fixLocation, turnOnScreenTime: turnOnScreenTime,
        chooseNightApps: chooseNightApps, openCard: openCard, dismissCard: dismissCard,
        putAwayLastNight: putAwayLastNight, openFlow: openFlow, notNowFlow: notNowFlow,
        flowShown: flowShown)
    )
    // Design §2.5: a card fades in place; nothing else moves.
    .animation(Motion.stateChange, value: home.band)
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
