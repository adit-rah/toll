import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// Welcome, the four questions (with Always when needed), then Ready (the canvas's onboarding).
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
          case .home: HomeMapView(model: model)
          case .permissions: PermissionsView(model: model)
          case .always: AlwaysView(model: model)
          case .locationOff: LocationOffView(model: model)
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
        OfferCard(price: model.app.price).padding(.bottom, 16)
        PrimaryButton(Copy.Setup.start) { model.go(.wake) }
        QuietButton(Copy.Setup.restore, type: .smallQuiet) {
          Task {
            restoring = true
            _ = await model.app.restore()
            restoring = false
            model.go(.wake)
          }
        }
        .disabled(restoring)
      }
    }
    .toolbar(.hidden, for: .navigationBar)
  }
}

/// "7 nights free · Then $9.99 once. No subscription. No account."
private struct OfferCard: View {
  let price: String

  var body: some View {
    HStack(spacing: TollSpacing.rowGap) {
      IconTile("moon", size: .large)
      VStack(alignment: .leading, spacing: 0) {
        Text(Copy.Setup.offerTitle)
          .tollType(TollType(size: 16, lineHeight: 21, weight: .semibold, style: .callout))
          .foregroundStyle(TollColor.label)
        Text(Copy.Setup.offerDetail(price: price))
          .tollType(TollType(size: 14, lineHeight: 20, weight: .regular, style: .subheadline))
          .foregroundStyle(TollColor.label2)
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

/// Ready: what was set up, and when the free week ends (the canvas's Ready and Ready · location While
/// Using). No back button: setup is done.
struct ReadyView: View {
  let model: SetupModel

  var body: some View {
    SetupPage(step: nil, title: line, eyebrow: Copy.Setup.readyEyebrow) {
      Card {
        CardRow(
          Copy.span(model.window),
          detail: model.weekendsDiffer ? Copy.Setup.weekendsDiffer : Copy.Setup.everyNight
        ) { IconTile("moon") }
        CardRow(
          atHome ? Copy.Setup.atHome : Copy.Setup.anywhere,
          detail: atHome ? Copy.Setup.yourBuilding : Copy.Setup.anywhereDetail
        ) { IconTile(atHome ? "house" : "location", accent: false) }
        CardRow(
          Copy.Setup.blocked,
          detail: Copy.Setup.blockedCount(
            categories: model.selection.categoryTokens.count,
            apps: Blocklist.items(model.selection))
        ) { IconTile("iphone", accent: false) }
        CardRow(
          Copy.Setup.unlocks(model.app.config.unlocks.max),
          detail: Copy.Setup.unlocksDetail(minutes: model.app.config.door.minutes)
        ) { IconTile("lock", accent: false) }
      }
      .padding(.top, TollSpacing.lineToContent)
    } actions: {
      if let end = model.trialEnds(after: Date()) {
        Footnote(
          Copy.Setup.freeUntil(
            end.formatted(.dateTime.month(.abbreviated).day()), price: model.app.price),
          alignment: .center
        )
        .padding(.horizontal, 12)
        .padding(.bottom, TollSpacing.aboveButton)
      }
      PrimaryButton(Copy.Setup.done) { model.finish() }
    }
    .navigationBarBackButtonHidden()
  }

  private var atHome: Bool { model.locationUsable && model.home != nil }

  private var line: String {
    let now = Date()
    if let night = model.schedule.occurrence(containing: now, calendar: .current) {
      return Copy.Setup.readyNow(Copy.time(night.end), atHome: atHome)
    }
    let start = model.schedule.nextStart(after: now, calendar: .current) ?? now
    return Copy.Setup.readyLine(Copy.time(start), atHome: atHome)
  }
}
