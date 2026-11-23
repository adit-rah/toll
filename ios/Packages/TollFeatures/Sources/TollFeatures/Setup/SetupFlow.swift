import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// Onboarding (D68): Welcome, when you get up, Screen Time, the apps, then Ready. Five screens to a
/// first locked night; home is offered after it (`SetHomeFlow`).
struct SetupFlow: View {
  @State private var model: SetupModel

  init(app: AppModel) {
    _model = State(initialValue: SetupModel(app: app))
  }

  var body: some View {
    SetupFlowContent(model: model)
  }
}

struct SetupFlowContent: View {
  @Bindable var model: SetupModel

  var body: some View {
    NavigationStack(path: $model.path) {
      WelcomeView(model: model)
        .navigationDestination(for: SetupModel.Step.self) { step in
          switch step {
          case .wake: WakeTimeView(model: model)
          case .screenTime: ScreenTimeView(model: model)
          case .blocklist: BlocklistView(model: model)
          case .ready: ReadyView(model: model)
          }
        }
    }
    .tint(TollColor.accent)
  }
}

/// Welcome: the promise, then the whole deal before anything else (P-1, D7). Title and line sit
/// centred in the space above the offer, as on the board.
struct WelcomeView: View {
  let model: SetupModel
  @State private var restoring = false
  @State private var nothingToRestore = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: 24)
      Text(Copy.Setup.welcomeTitle)
        .tollType(.display, TollColor.label)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
      Text(Copy.Setup.welcomeLine)
        .tollType(.lead, TollColor.label2)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 16)
      Spacer(minLength: 24)
    }
    .tollGutter()
    .padding(.top, TollSpacing.barHeight)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(TollColor.bg)
    .tollBottomBar(endsWithLink: true) {
      VStack(spacing: 0) {
        let offer = model.offer(now: Date())
        OfferCard(offer: offer, price: model.app.price).padding(.bottom, 16)
        PrimaryButton(offer.isFree ? Copy.Setup.start : Copy.Setup.setUp) { model.go(.wake) }
        // Found, the card says Purchased and setup goes on from the button; not found, the user is
        // told and stays here (#46).
        QuietButton(Copy.Setup.restore, type: .smallQuiet) {
          Task {
            restoring = true
            nothingToRestore = !(await model.app.restore())
            restoring = false
          }
        }
        .disabled(restoring || offer == .purchased)
        .opacity(offer == .purchased ? 0 : 1)
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .sheet(isPresented: $nothingToRestore) { RestoreNoneSheet() }
  }
}

extension Trial.Offer {
  var isFree: Bool {
    switch self {
    case .fresh, .running: true
    case .used, .purchased: false
    }
  }
}

/// "7 nights free · Then $9.99 once. No subscription. No account.", or what this phone already
/// used or bought (#46).
private struct OfferCard: View {
  let offer: Trial.Offer
  let price: String

  private var title: String {
    switch offer {
    case .fresh, .running: Copy.Setup.offerTitle
    case .used: Copy.Setup.offerUsedTitle
    case .purchased: Copy.Setup.offerPurchasedTitle
    }
  }

  private var detail: String {
    switch offer {
    case .fresh, .running: Copy.Setup.offerDetail(price: price)
    case .used(let ended):
      Copy.Setup.offerUsedDetail(
        ended.formatted(.dateTime.month(.abbreviated).day()), price: price)
    case .purchased: Copy.Setup.offerPurchasedDetail
    }
  }

  var body: some View {
    HStack(spacing: TollSpacing.rowGap) {
      IconTile(offer == .purchased ? .purchased : .sleep, size: .large)
      VStack(alignment: .leading, spacing: 0) {
        Text(title)
          .tollType(TollType(size: 16, lineHeight: 21, weight: .semibold, style: .callout))
          .foregroundStyle(TollColor.label)
        Text(detail)
          .tollType(TollType(size: 14, lineHeight: 20, weight: .regular, style: .subheadline))
          .foregroundStyle(TollColor.label2)
        // The deal as a shape before the first tap: seven free nights, none used (#77).
        if case .fresh = offer {
          Pips(filled: 0, total: 7, style: .segments, spoken: Copy.Setup.offerTitle)
            .padding(.top, 6)
        }
      }
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(TollSpacing.cardPadding)
    .background(
      TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous)
    )
    .accessibilityElement(children: .combine)
  }
}
