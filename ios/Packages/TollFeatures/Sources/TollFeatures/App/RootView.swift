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
    TollChrome.apply()
  }

  public var body: some View {
    content
      .preferredColorScheme(scheme)
      .onChange(of: scenePhase, initial: true) { _, phase in
        if phase == .active { model.foreground() }
        // The heads-up's answer shows once (#160).
        if phase == .background { model.headsUpTurnedOn = false }
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
  /// Before bed's helpers, from the capsule or its card (D80).
  @State private var helpersUp = false
  /// One-time flow #1, "Fit Dusk to your sleep", from its card (#144).
  @State private var fitting = false
  /// One-time flow #2, personal timing, from its card (#171).
  @State private var offeringTiming = false

  var body: some View {
    DuskTabs(
      tab: $tab, tonightPath: $path, blocksPath: $blocksPath, model: model,
      sleep: YourSleep(
        state: model.state, log: model.log, history: model.history, now: Date(),
        calendar: .current),
      openPurchase: { buying = true }
    ) {
      TimelineView(.everyMinute) { context in
        HomeView(
          home: snapshot(context.date), price: model.price,
          locationFact: locationFact(model.location),
          openSettings: { path.append(.settings) },
          // The sheet can be swiped away during a pause, so Tonight's capsule brings it back.
          openDoor: {
            model.askDoor()
            doorUp = true
          },
          lockAgain: { model.lockDoor() },
          openPurchase: { buying = true }, fixLocation: openSystemSettings,
          turnOnScreenTime: { Task { await model.turnOnScreenTime() } },
          chooseNightApps: {
            if let night = model.state.sleepBlock?.id { path.append(.nightApps(night)) }
          },
          openCard: { card in
            switch card {
            case .home: settingHome = true
            case .headsUp: Task { await model.turnOnHeadsUp(fromOffer: true) }
            case .gapWeek, .gapOffer: model.openGapCard(card)
            // Shown once: opening it answers it.
            case .beforeBed:
              model.dismiss(.beforeBed)
              helpersUp = true
            }
          },
          dismissCard: { model.dismiss($0) },
          // Opening them answers their card too.
          openHelpers: {
            if !model.state.dismissed(.beforeBed) { model.dismiss(.beforeBed) }
            helpersUp = true
          },
          putAwayLastNight: { model.putAwayLastNight($0) },
          // Pushed on Tonight, so Back returns to the strip it came from (D75).
          openBlock: { path.append(.block($0)) },
          openFlow: {
            if dueFlow(Date()) == Flows.timing.id { offeringTiming = true } else { fitting = true }
          },
          notNowFlow: { if let id = dueFlow(Date()) { model.flow(id, .notNow) } },
          flowShown: { if let id = dueFlow(Date()) { model.flow(id, .shown) } },
          headsUpSeen: { model.headsUpTurnedOn = false },
          openNotificationSettings: openSystemSettings
        )
        .sheet(isPresented: $settingHome) { SetHomeFlow(app: model) { settingHome = false } }
        .sheet(isPresented: $fitting) { FitFlowSheet(app: model) { fitting = false } }
        .sheet(isPresented: $offeringTiming) {
          TimingOfferSheet(app: model) { offeringTiming = false }
        }
        .sheet(isPresented: $helpersUp) { HelpersSheet(model: model) { helpersUp = false } }
      }
    }
    .sheet(isPresented: $buying) { PurchaseSheet(model: model, home: snapshot(Date())) }
    // "See how you slept" on last night's card and Your sleep's link to Health (#86).
    .environment(\.askHealth, { [model] in Task { await model.askHealth() } })
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
      screenTime: model.screenTime == .approved,
      // Not read yet: no offer, rather than one that vanishes a moment later.
      notifications: model.notifications ?? .allowed, history: model.history,
      readOnly: model.readOnly, flow: dueFlow(now), headsUpTurnedOn: model.headsUpTurnedOn)
  }

  /// The one-time flow due now (`Flows.due`), read with the clock so the band follows the day:
  /// none in the hour before the lock or during the night.
  private func dueFlow(_ now: Date) -> String? {
    Flows.due(model.state, now: now, calendar: .current, config: model.config)?.id
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
    case .block(let id): BlockEditorView(app: model, editing: id)
    case .nightApps(let id): BlockEditorView(app: model, editing: id, pickingApps: true)
    case .log: TransitionLogView(model: model)
    case .sleep: SleepSettingsView(model: model)
    }
  }
}

/// Screens pushed from Tonight, with Apple's back button reading "Tonight" (D75: "Home" is also the
/// place).
enum HomeRoute: Hashable {
  case settings, log
  /// Settings › Sleep: sleep and both buffers (#144).
  case sleep
  /// A block to edit, or nil for a new one; pushed over Blocks, or over Tonight from the strip's
  /// snippet (D75), so Back returns where it came from.
  case block(BlockID?)
  /// The night's editor with Apple's apps picker already open: the night came back without its apps
  /// (#140).
  case nightApps(BlockID)
}

extension View {
  /// Home draws its own bar; its title is what the back button reads on the screens it pushes.
  func homeNavigation() -> some View {
    navigationTitle(Copy.Home.backTitle).toolbar(.hidden, for: .navigationBar)
  }
}
