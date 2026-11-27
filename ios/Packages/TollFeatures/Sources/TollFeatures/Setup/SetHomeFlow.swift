import SwiftUI
import TollCore
import TollUI

/// "Only when I'm home" as a sheet over Tonight or Settings (D68): the map, the location prompts and
/// Always, each pushed as in onboarding.
struct SetHomeFlow: View {
  @State private var model: SetHomeModel

  init(app: AppModel, done: @escaping () -> Void) {
    _model = State(initialValue: SetHomeModel(app: app, done: done))
  }

  var body: some View {
    SetHomeFlowContent(model: model)
  }
}

struct SetHomeFlowContent: View {
  @Bindable var model: SetHomeModel

  var body: some View {
    NavigationStack(path: $model.path) {
      HomeMapView(model: model)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(Copy.Setup.cancel) { model.cancel() }
          }
        }
        .navigationDestination(for: SetHomeModel.Step.self) { step in
          switch step {
          case .location: LocationView(model: model)
          case .always: AlwaysView(model: model)
          case .locationOff: LocationOffView(model: model)
          }
        }
    }
    .setupProgress(
      step: model.path.isEmpty ? SetHomeModel.mapStep : SetHomeModel.locationStep,
      of: SetHomeModel.questions, inset: 72
    )
    .tint(TollColor.accent)
  }
}
