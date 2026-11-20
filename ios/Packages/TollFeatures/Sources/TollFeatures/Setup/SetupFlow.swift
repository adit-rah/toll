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
          case .blocklist: BlocklistView(model: model)
          case .ready: ReadyView(model: model)
          }
        }
    }
    .tint(TollColor.accent)
  }
}

/// Welcome: the promise, then the whole deal before anything else (P-1, D7).
struct WelcomeView: View {
  let model: SetupModel
  @State private var restoring = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: TollSpacing.sectionGap)
      Text(Copy.Setup.welcomeTitle)
        .font(.system(.largeTitle, weight: .semibold))
        .foregroundStyle(TollColor.label)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
      Text(Copy.Setup.welcomeLine)
        .font(.title3)
        .foregroundStyle(TollColor.label2)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 16)
      Spacer(minLength: TollSpacing.sectionGap)
      Card {
        CardRow(Copy.Setup.offerTitle, detail: Copy.Setup.offerDetail(price: model.app.price)) {
          IconTile("moon.fill", size: .large)
        }
      }
    }
    .tollGutter()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(TollColor.bg)
    .tollBottomBar(background: TollColor.bg) {
      VStack(spacing: 0) {
        PrimaryButton(Copy.Setup.start) { model.go(.wake) }
        QuietButton(Copy.Setup.restore, tone: .secondary) {
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

/// Ready: what was set up, and when the free week ends (the canvas).
struct ReadyView: View {
  let model: SetupModel

  var body: some View {
    SetupPage(step: nil, title: Copy.Setup.readyTitle, subtitle: line) {
      Card {
        CardRow(
          Copy.span(model.window),
          detail: model.weekendsDiffer ? Copy.Setup.weekendsDiffer : Copy.Setup.everyNight
        ) { IconTile("moon.fill") }
        CardRow(
          Copy.Setup.atHome,
          detail: atHome ? Copy.Setup.yourBuilding : Copy.Setup.anywhere
        ) { IconTile("location.fill", accent: false) }
        CardRow(
          Copy.Setup.blocked,
          detail: Copy.Setup.blockedCount(
            apps: Blocklist.items(model.selection), categories: model.selection.categoryTokens.count
          )
        ) { IconTile("nosign", accent: false) }
        CardRow(
          Copy.Setup.unlocks(model.app.config.unlocks.max),
          detail: Copy.Setup.unlocksDetail(minutes: model.app.config.door.minutes)
        ) { IconTile("key.fill", accent: false) }
      }
      if let end = model.trialEnds(after: Date()) {
        Footnote(
          Copy.Setup.freeUntil(
            end.formatted(.dateTime.month(.abbreviated).day()), price: model.app.price))
      }
    } actions: {
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
