import SwiftUI
import TollUI

/// The one window: setup until it is finished, then the main screen.
public struct RootView: View {
  let model: AppModel
  @Environment(\.scenePhase) private var scenePhase
  @State private var showsSettings = false

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
      LiveStatus(model: model, openSettings: { showsSettings = true })
        .sheet(isPresented: $showsSettings) { TriggerView(model: model) }
    }
  }
}

/// Status on the live state. Extensions change the state while the app is open (the window starting,
/// the block screen's buttons), so it is read again every so often and the clock moves on with it.
private struct LiveStatus: View {
  let model: AppModel
  let openSettings: () -> Void

  var body: some View {
    TimelineView(.everyMinute) { context in
      StatusView(state: model.state, now: context.date, openSettings: openSettings)
    }
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(20))
        model.refresh()
      }
    }
  }
}
