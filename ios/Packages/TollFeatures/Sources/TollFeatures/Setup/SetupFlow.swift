import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// Onboarding (D68, #144): Welcome, Fit Dusk to your sleep, your sleep, the time around it, Screen
/// Time, the apps, then Ready. Home is offered after the first night (`SetHomeFlow`).
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
          case .fit: FitView(model: model)
          case .sleep:
            SleepTimesStep(draft: model.draft) { model.go(.around) }
          case .around:
            AroundStep(draft: model.draft) { model.go(.screenTime) }
          case .screenTime: ScreenTimeView(model: model)
          case .blocklist: BlocklistView(model: model)
          case .ready: ReadyView(model: model)
          }
        }
    }
    .setupProgress(step: model.path.last?.number, of: SetupModel.Step.questions)
    .tint(TollColor.accent)
  }
}

/// Welcome: the promise, then the whole deal before anything else (P-1, D7). Title and line sit
/// centred in the space above the offer, as on the board.
struct WelcomeView: View {
  let model: SetupModel
  @State private var restoring = false
  @State private var nothingToRestore = false
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    let offer = model.offer(now: Date())
    Group {
      // At accessibility sizes the promise and the offer scroll and the button stays pinned
      // (design §2.1); otherwise they wouldn't fit and the button would sit below the screen.
      if typeSize.isAccessibilitySize {
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            promise
            OfferCard(offer: offer, price: model.app.price, nights: model.app.config.trial.nights)
              .padding(.top, 24)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .tollGutter()
          .padding(.top, TollSpacing.barHeight)
          .padding(.bottom, 24)
        }
        .background(TollColor.bg)
        .tollBottomBar(endsWithLink: true) { actions(offer) }
      } else {
        VStack(alignment: .leading, spacing: 0) {
          Spacer(minLength: 24)
          promise
          Spacer(minLength: 24)
        }
        .tollGutter()
        .padding(.top, TollSpacing.barHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(TollColor.bg)
        .tollBottomBar(endsWithLink: true) {
          VStack(spacing: 0) {
            OfferCard(offer: offer, price: model.app.price, nights: model.app.config.trial.nights)
              .padding(.bottom, 16)
            actions(offer)
          }
        }
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .sheet(isPresented: $nothingToRestore) { RestoreNoneSheet() }
  }

  private var promise: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(Copy.Setup.welcomeTitle)
        .tollType(.display, TollColor.label)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
      Text(Copy.Setup.welcomeLine)
        .tollType(.lead, TollColor.label2)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 16)
    }
  }

  @ViewBuilder private func actions(_ offer: Trial.Offer) -> some View {
    VStack(spacing: 0) {
      PrimaryButton(
        offer.isFree ? Copy.Fit.start(nights: model.app.config.trial.nights) : Copy.Setup.setUp
      ) { model.go(.fit) }
      // The whole purchase, quieter, under the free nights (#144): bought or not, setup goes on.
      // Once bought, its room stays, so a restore found here moves nothing (#135).
      if offer != .purchased {
        QuietButton(Copy.Fit.buyNow(model.app.price)) {
          Task { await model.buyNow() }
        }
        .disabled(model.buying || restoring)
      } else {
        LinkRoom()
      }
      // Found, the card says Purchased and setup goes on from the button; not found, the user is
      // told and stays here (#46). Once bought the link keeps its room, so the button stays put.
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
}

extension Trial.Offer {
  var isFree: Bool {
    switch self {
    case .fresh, .running: true
    case .used, .purchased: false
    }
  }
}

/// "14 nights free · Then $9.99 once. No subscription. No account.", or what this phone or Apple
/// ID already used or bought (#46, D78).
private struct OfferCard: View {
  let offer: Trial.Offer
  let price: String
  let nights: Int

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
        // The deal as a shape before the first tap: two weeks of free nights, none used (#77).
        if case .fresh = offer {
          FreeNights(used: 0, total: nights, spoken: Copy.Setup.offerTitle).padding(.top, 6)
        }
      }
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(TollSpacing.cardPadding)
    .tollSurface()
    .accessibilityElement(children: .combine)
  }
}
