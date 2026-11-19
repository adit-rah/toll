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
      .preferredColorScheme(appearance.scheme)
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
      LiveHome(model: model)
    }
  }
}

/// Home on the live state, with its sheets. Extensions change the state while the app is open (a
/// window starting, the block screen's buttons), so it is read again every so often and the clock
/// moves on with it.
struct LiveHome: View {
  let model: AppModel
  @State private var sheet: HomeSheet?
  @State private var editing: BlockRef?

  var body: some View {
    TimelineView(.everyMinute) { context in
      let home = HomeSnapshot(
        state: model.state, log: model.log, now: context.date, calendar: .current)
      HomeView(
        home: home, price: model.price,
        openSettings: { sheet = .settings }, openDoor: { model.askDoor() },
        openPurchase: { sheet = .purchase }, fixLocation: openSystemSettings,
        openBlock: { editing = BlockRef(id: $0) }
      )
      .sheet(item: $editing) { ref in BlockEditorView(app: model, editing: ref.block) }
      .sheet(item: $sheet) { which in
        switch which {
        case .settings:
          SettingsView(model: model) {
            // Settings closes itself first; the purchase sheet opens once it has gone.
            Task {
              try? await Task.sleep(for: .milliseconds(450))
              sheet = .purchase
            }
          }
        case .purchase: PurchaseSheet(model: model, home: home)
        }
      }
      .sheet(isPresented: doorShown) {
        TimelineView(.periodic(from: .now, by: 1)) { tick in
          DoorSheet(model: model, now: tick.date)
        }
        .interactiveDismissDisabled(model.state.door != nil)
      }
    }
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(20))
        model.refresh()
      }
    }
  }

  private var doorShown: Binding<Bool> {
    Binding(get: { model.showsDoor }, set: { if !$0 { model.dismissDoor() } })
  }

  private func openSystemSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }
}

enum HomeSheet: String, Identifiable {
  case settings, purchase
  var id: String { rawValue }
}
