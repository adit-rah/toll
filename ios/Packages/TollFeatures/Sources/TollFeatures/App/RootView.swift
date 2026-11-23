import SwiftUI
import TollCore
import TollUI
import UIKit

/// The one window: setup until it is finished, then Home.
public struct RootView: View {
  let model: AppModel
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage(Appearance.key) private var appearance = Appearance.standard

  public init(model: AppModel) {
    self.model = model
  }

  public var body: some View {
    content
      .preferredColorScheme(scheme)
      .onChange(of: scenePhase, initial: true) { _, phase in
        if phase == .active { model.foreground() }
      }
  }

  /// Demo launches follow the simulator, so renders show both appearances (docs/renders.md).
  private var scheme: ColorScheme? {
    #if DEBUG
      if DemoScenario.current != nil { return nil }
    #endif
    return appearance.scheme
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
      LiveHome(model: model)
    }
  }
}

/// Home on the live state, with the screens it pushes and its sheets. Extensions change the state
/// while the app is open (a window starting, the block screen's buttons), so it is read again every
/// so often and the clock moves on with it.
struct LiveHome: View {
  let model: AppModel
  @State private var buying = false
  @State private var tab = DuskTab.tonight
  @State private var path: [HomeRoute] = []
  @State private var blocksPath: [HomeRoute] = []
  /// The door sheet, opened by `showsDoor` and kept by `doorPending`.
  @State private var doorUp = false
  /// "Only when I'm home", from Tonight's card (D68).
  @State private var settingHome = false

  var body: some View {
    DuskTabs(
      tab: $tab, tonightPath: $path, blocksPath: $blocksPath, model: model,
      sleep: YourSleep(
        state: model.state, log: model.log, history: model.history, now: Date(),
        calendar: .current),
      log: model.trialSummaryLog(), openPurchase: { buying = true }
    ) {
      TimelineView(.everyMinute) { context in
        HomeView(
          home: snapshot(context.date), price: model.price,
          locationFact: locationFact(model.location),
          openSettings: { path.append(.settings) }, openDoor: { model.askDoor() },
          openPurchase: { buying = true }, fixLocation: openSystemSettings,
          turnOnScreenTime: { Task { await model.turnOnScreenTime() } },
          openCard: { card in
            switch card {
            case .home: settingHome = true
            }
          },
          dismissCard: { model.dismiss($0) }
        )
        .sheet(isPresented: $settingHome) { SetHomeFlow(app: model) { settingHome = false } }
      }
    }
    .sheet(isPresented: $buying) { PurchaseSheet(model: model, home: snapshot(Date())) }
    .onChange(of: model.showsDoor, initial: true) { _, shows in
      if shows { doorUp = true }
    }
    .onChange(of: model.doorPending) { _, pending in
      if !pending { doorUp = false }
    }
    .sheet(isPresented: doorShown) {
      TimelineView(.periodic(from: .now, by: 1)) { tick in
        DoorSheet(model: model, now: tick.date)
      }
      .interactiveDismissDisabled(model.state.door != nil)
    }
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(20))
        model.refresh()
      }
    }
  }

  private func snapshot(_ now: Date) -> HomeSnapshot {
    HomeSnapshot(
      state: model.state, log: model.log, now: now, calendar: .current,
      screenTime: model.screenTime == .approved)
  }

  private var doorShown: Binding<Bool> {
    Binding(
      get: { doorUp },
      set: { up in
        doorUp = up
        if !up, model.state.door == nil { model.dismissDoor() }
      })
  }
}

/// The screen for a route, shared by the live app and demo launches.
struct HomeDestination: View {
  let model: AppModel
  let route: HomeRoute
  let openPurchase: () -> Void

  var body: some View {
    switch route {
    case .settings: SettingsView(model: model, openPurchase: openPurchase)
    case .blocks: BlocksView(model: model)
    case .block(let id): BlockEditorView(app: model, editing: id)
    case .log: TransitionLogView(model: model)
    }
  }
}

/// Screens pushed from Home, with Apple's back button reading "Home" (the canvas).
enum HomeRoute: Hashable {
  case settings, blocks, log
  /// A block to edit, or nil for a new one; pushed over Blocks so the back button reads "Blocks".
  case block(BlockID?)
}

extension View {
  /// Home draws its own bar; its title is what the back button reads on the screens it pushes.
  func homeNavigation() -> some View {
    navigationTitle(Copy.Home.backTitle).toolbar(.hidden, for: .navigationBar)
  }
}
