import SwiftUI
import TollCore
import TollUI

/// Tonight's band, laid out from `TonightBand`: at most one card, and last night's row under it,
/// nearest the strip. While last night is open, the card above fades out (design §2.5, "A card or
/// note arrives or leaves") so the open card grows into its room without pushing it into the state
/// or covering it; folding brings it back the same way.
struct TonightBandView: View {
  let home: HomeSnapshot
  var locationFact = Copy.Setup.whileUsingFact
  @Binding var lastNightOpen: Bool
  var actions = TonightBandActions()

  /// Two items sit as far apart as the card under the pill at accessibility sizes (D48).
  private static let between: CGFloat = 12

  var body: some View {
    VStack(spacing: Self.between) {
      if let card = home.band.card, !(lastNightOpen && home.band.hasLastNight) {
        item(card)
          .transition(.opacity.animation(Motion.stateChange))
          .id(card)
      }
      if home.band.hasLastNight, let night = home.lastNight {
        LastNightBand(night: night, open: $lastNightOpen) {
          lastNightOpen = false
          actions.putAwayLastNight(night.night)
        }
      }
    }
    .accessibilityElement(children: .contain)
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
    .tollSurface()
  }
}
