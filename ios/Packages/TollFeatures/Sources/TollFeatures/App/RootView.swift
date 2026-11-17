import SwiftUI
import TollUI

/// The one window. Until setup and Status exist (spec §12 steps 4–5) it shows the trigger screen
/// used for device testing.
public struct RootView: View {
  let model: AppModel
  @Environment(\.scenePhase) private var scenePhase

  public init(model: AppModel) {
    self.model = model
  }

  public var body: some View {
    TriggerView(model: model)
      .onChange(of: scenePhase, initial: true) { _, phase in
        if phase == .active { model.foreground() }
      }
  }
}
