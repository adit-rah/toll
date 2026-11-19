import SwiftUI
import TollCore
import TollUI

/// Welcome, then the four questions, then Ready (spec §7 Setup). Shown until setup is finished.
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
      WelcomeView(price: model.app.price) { model.go(.wake) }
        .navigationDestination(for: SetupModel.Step.self) { step in
          switch step {
          case .wake: WakeTimeView(model: model)
          case .home: HomeMapView(model: model)
          case .permissions: PermissionsView(model: model)
          case .blocklist: BlocklistView(model: model)
          case .ready: ReadyView(model: model)
          }
        }
    }
    .tint(TollColor.accent)
  }
}

struct WelcomeView: View {
  let price: String
  let start: () -> Void

  var body: some View {
    SetupPage(step: nil, title: Copy.name) {
      SetupLine(Copy.offer(price: price))
    } actions: {
      PrimaryButton(Copy.Setup.start, action: start)
    }
  }
}

struct ReadyView: View {
  let model: SetupModel

  var body: some View {
    SetupPage(step: nil, title: title) {
      EmptyView()
    } actions: {
      PrimaryButton(Copy.Setup.ok) { model.finish() }
    }
    .navigationBarBackButtonHidden()
  }

  private var title: String {
    let now = Date()
    let windowOnly = !model.locationUsable || model.home == nil
    if let night = model.window.night(containing: now, calendar: .current) {
      return Copy.Setup.readyNow(Copy.time(night.end), windowOnly: windowOnly)
    }
    let start = model.window.nextStart(after: now, calendar: .current) ?? now
    return Copy.Setup.readyTitle(Copy.time(start), windowOnly: windowOnly)
  }
}
