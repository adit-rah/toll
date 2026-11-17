import SwiftUI
import TollUI

/// The one window: setup until it is finished, then the main screen.
public struct RootView: View {
  let model: AppModel
  @Environment(\.scenePhase) private var scenePhase

  public init(model: AppModel) {
    self.model = model
  }

  public var body: some View {
    content
      .onChange(of: scenePhase, initial: true) { _, phase in
        if phase == .active { model.foreground() }
      }
  }

  @ViewBuilder private var content: some View {
    #if DEBUG
      if let demo = DemoScenario.current {
        DemoRoot(app: model, scenario: demo)
      } else {
        live
      }
    #else
      live
    #endif
  }

  @ViewBuilder private var live: some View {
    if model.state.setupFinishedAt == nil {
      SetupFlow(app: model)
    } else {
      TriggerView(model: model)
    }
  }
}
