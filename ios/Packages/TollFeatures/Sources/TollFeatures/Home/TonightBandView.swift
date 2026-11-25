import SwiftUI
import TollCore
import TollUI

/// Tonight's band, laid out from `TonightBand`: at most one card, and last night's row under it,
/// nearest the strip. While last night is open, the card above fades out in place (design §2.5),
/// so nothing is pushed into the state; folding brings it back the same way.
struct TonightBandView: View {
  let home: HomeSnapshot
  var locationFact = Copy.Setup.whileUsingFact
  @Binding var lastNightOpen: Bool
  /// Below accessibility sizes the band keeps its bottom edge above the strip and last night opens
  /// upward; at accessibility sizes it sits in the column and opens downward.
  var growsUp = true
  var actions = TonightBandActions()

  /// Two items sit as far apart as the card under the pill at accessibility sizes (D48).
  private static let between: CGFloat = 12

  private var night: Morning? { home.band.hasLastNight ? home.lastNight : nil }

  var body: some View {
    Group {
      if growsUp {
        // The card sits over a hidden copy of the folded row and the row lies over both, so the
        // card keeps its place while hidden and the open card grows over its room.
        ZStack(alignment: .bottom) {
          VStack(spacing: Self.between) {
            card(hidden: lastNightOpen && night != nil)
            if let night { LastNightBand(night: night, open: .constant(false), putAway: {}).hidden() }
          }
          lastNight
        }
      } else {
        VStack(spacing: Self.between) {
          if !(lastNightOpen && night != nil) { card(hidden: false) }
          lastNight
        }
      }
    }
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder private func card(hidden: Bool) -> some View {
    if let card = home.band.card {
      item(card)
        .opacity(hidden ? 0 : 1)
        .animation(Motion.stateChange, value: hidden)
        .allowsHitTesting(!hidden)
        .accessibilityHidden(hidden)
        .transition(.opacity.animation(Motion.stateChange))
        .id(card)
    }
  }

  @ViewBuilder private var lastNight: some View {
    if let night {
      LastNightBand(night: night, open: $lastNightOpen) {
        lastNightOpen = false
        actions.putAwayLastNight(night.night)
      }
    }
  }

  @ViewBuilder private func item(_ item: TonightBand.Item) -> some View {
    switch item {
    case .screenTimeOff:
      NoteCard(Copy.Home.screenTimeOffCard, severity: .broken) {
        SettingsLink(Copy.Home.turnOn, action: actions.turnOnScreenTime)
      }
    case .readOnly:
      NoteCard(Copy.Home.readOnlyCard, severity: .degraded)
    case .recovered:
      NoteCard(Copy.Home.recoveredCard, severity: .degraded) {
        SettingsLink(Copy.Home.chooseApps, action: actions.chooseNightApps)
      }
    case .location:
      NoteCard(locationFact, severity: .degraded) {
        SettingsLink(Copy.Home.fixInSettings, action: actions.fixLocation)
      }
    case .card(let card):
      TonightCardView(
        card: card, headsUp: home.headsUp, gap: home.gapCard, untilBed: home.untilBed,
        open: { actions.openCard(card) }, dismiss: { actions.dismissCard(card) })
    case .flow:
      FlowCardView(open: actions.openFlow, notNow: actions.notNowFlow)
        .onAppear(perform: actions.flowShown)
    case .lastNight:
      EmptyView()
    }
  }
}

/// What the band's items do; Tonight passes its own.
struct TonightBandActions {
  var fixLocation: () -> Void = {}
  var turnOnScreenTime: () -> Void = {}
  var chooseNightApps: () -> Void = {}
  var openCard: (TonightCard) -> Void = { _ in }
  var dismissCard: (TonightCard) -> Void = { _ in }
  var putAwayLastNight: (Date) -> Void = { _ in }
  var openFlow: () -> Void = {}
  var notNowFlow: () -> Void = {}
  var flowShown: () -> Void = {}
}

/// A one-time flow's card (D92), as quiet as an offer, until the flow brings its own words.
struct FlowCardView: View {
  let open: () -> Void
  let notNow: () -> Void
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    HStack(alignment: .top, spacing: TollSpacing.rowGap) {
      IconTile(.sleep, accent: false)
      VStack(alignment: .leading, spacing: 0) {
        RowText(title: Copy.Band.flowTitle, detail: Copy.Band.flowDetail)
          .accessibilityElement(children: .combine)
        let actions =
          typeSize.isAccessibilitySize
          ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
          : AnyLayout(HStackLayout(spacing: 20))
        actions {
          Button(action: open) {
            HStack(spacing: 4) {
              Text(Copy.Band.flowAction)
              Image(symbol: .forward).unredacted()
                .font(.system(size: 12, weight: .bold))
                .accessibilityHidden(true)
            }
          }
          .tollType(.action, TollColor.accent)
          .frame(minHeight: TollSpacing.minTapTarget)
          Button(Copy.Home.notNow, action: notNow)
            .tollType(.action, TollColor.label2)
            .frame(minHeight: TollSpacing.minTapTarget)
        }
        .padding(.top, 2)
      }
    }
    .padding(.top, TollSpacing.noteCardVertical)
    .padding(.bottom, 2)
    .padding(.horizontal, TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }
}
