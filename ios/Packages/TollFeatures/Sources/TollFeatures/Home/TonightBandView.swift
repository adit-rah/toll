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
        // card keeps its place while hidden and the open card grows over its room. Offered less
        // room than it would like (#162), only the open card gives way: it scrolls inside.
        ZStack(alignment: .bottom) {
          VStack(spacing: Self.between) {
            card(hidden: lastNightOpen && night != nil)
            if let night {
              LastNightBand(night: night, open: .constant(false), putAway: {}).hidden()
            }
          }
          .fixedSize(horizontal: false, vertical: true)
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
        .animation(Motion.stateChange) { $0.opacity(hidden ? 0 : 1) }
        .allowsHitTesting(!hidden)
        .accessibilityHidden(hidden)
        .transition(.opacity.animation(Motion.stateChange))
        .id(card)
    }
  }

  @ViewBuilder private var lastNight: some View {
    if let night {
      LastNightBand(night: night, open: $lastNightOpen, scrollsInside: growsUp) {
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
      // Each note its own glyph, so neither reads as the location note (#70, one concept per
      // symbol): changes that can't be saved, and a night that came back without its apps.
      NoteCard(Copy.Home.readOnlyCard, symbol: .readOnly, severity: .degraded)
    case .recovered:
      NoteCard(Copy.Home.recoveredCard, symbol: .apps, severity: .degraded) {
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
    // The offer's answer (#160): the bell on, with its time; or refused, the way to iOS Settings.
    case .headsUpOn:
      BandCard(
        symbol: .headsUp, title: Copy.HeadsUp.isOn,
        detail: Copy.HeadsUp.cardDetail(
          time: home.headsUp.map { Copy.time($0.at) },
          minutes: TollConfig.defaults.headsUp.leadMinutes),
        action: nil, dismiss: Copy.HeadsUp.ok, done: true, open: {},
        putAway: actions.headsUpSeen)
    case .headsUpDenied:
      BandCard(
        symbol: .headsUp, title: Copy.HeadsUp.refused, detail: Copy.HeadsUp.refusedDetail,
        action: Copy.HeadsUp.openSettings, dismiss: Copy.HeadsUp.ok, leaves: true,
        open: actions.openNotificationSettings, putAway: actions.headsUpSeen)
    case .flow(let id):
      // Each one-time flow in its own words, on the offers' quiet card: #1 Fit Dusk to your sleep
      // (#144), #2 personal timing (#171).
      Group {
        if id == Flows.timing.id {
          BandCard(
            symbol: .timing, title: Copy.Timing.cardTitle,
            detail: Copy.Timing.cardDetail(TollConfig.defaults.timing.mostMinutes),
            action: Copy.Timing.cardAction, dismiss: Copy.Home.notNow, open: actions.openFlow,
            putAway: actions.notNowFlow)
        } else {
          BandCard(
            symbol: .sleep, title: Copy.Fit.cardTitle, detail: Copy.Fit.cardDetail,
            action: Copy.Fit.cardAction, dismiss: Copy.Home.notNow, open: actions.openFlow,
            putAway: actions.notNowFlow)
        }
      }
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
  /// The heads-up's answer (#160): "OK" puts it away; refused, iOS Settings allows it.
  var headsUpSeen: () -> Void = {}
  var openNotificationSettings: () -> Void = {}
}
