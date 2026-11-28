#if DEBUG
  import SwiftUI
  import TollCore
  import TollUI

  /// Home in one of its states, with the door or the purchase sheet over it where the scenario says.
  struct DemoHome: View {
    let app: AppModel
    let scenario: DemoScenario
    /// The purchase sheet from the pill, so a scripted tap on it opens what the app's does (D75).
    @State private var buying: Bool

    init(app: AppModel, scenario: DemoScenario) {
      self.app = app
      self.scenario = scenario
      _buying = State(initialValue: scenario == .homePillPurchase)
    }

    var body: some View {
      let now = DemoClock.now(for: scenario)
      let fixture = DemoFixture(scenario: scenario, now: now)
      let home = HomeSnapshot(
        state: fixture.state, log: fixture.log, now: now, calendar: .current,
        screenTime: scenario != .homeScreenTimeOff,
        notifications: scenario.notifications ?? .allowed, history: fixture.history,
        readOnly: scenario == .homeReadOnly, flow: scenario.flow,
        headsUpTurnedOn: scenario.headsUpAnswered)
      DuskTabs(
        tab: .constant(scenario.tab),
        tonightPath: .constant(scenario.tab == .tonight ? scenario.routes : []),
        blocksPath: .constant(scenario.tab == .blocks ? scenario.routes : []), model: app,
        sleep: YourSleep(
          state: fixture.state, log: fixture.log, history: fixture.history, now: now,
          calendar: .current),
        openPurchase: {}
      ) {
        HomeView(
          home: home, price: Copy.fallbackPrice,
          openSettings: {}, openDoor: {},
          openPurchase: { buying = true }, fixLocation: {}, snippet: scenario.snippet,
          lastNightStartsOpen: [
            .homeMorningOpen, .homeMorningLandmarkOpen, .homeMorningCardOpen,
            .homeMorningAsleepOpen, .homeMorningAskOpen,
          ]
          .contains(scenario)
        )
        .sheet(isPresented: $buying) { PurchaseSheet(model: app, home: home) }
      }
      .environment(\.skyDemoFocus, scenario.skyFocus)
      // Health's ask shows as it would; in a demo it does nothing.
      .environment(\.askHealth, {})
      .sheet(isPresented: .constant(scenario.presentsSheet)) {
        switch scenario {
        case .purchase: PurchaseSheet(model: app, home: home)
        case .purchasePending: PurchaseSheet(model: app, home: home, outcome: .pending)
        case .purchaseFailed: PurchaseSheet(model: app, home: home, outcome: .failed)
        case .purchaseRestoreNone:
          PurchaseSheet(model: app, home: home, outcome: .nothingToRestore)
        case .purchaseDone: PurchaseSheet(model: app, home: home, outcome: .purchased)
        case .settingsHowItWorks: HowItWorks(config: app.config)
        case _ where scenario.setHomePath != nil:
          DemoSetHome(app: app, path: scenario.setHomePath ?? [])
        case _ where scenario.fitSheetPath != nil:
          FitFlowSheet(app: app, path: scenario.fitSheetPath ?? []) {}
        case _ where scenario.helperSheet:
          HelpersSheet(
            model: app, page: scenario.helperPage,
            demoUntil: scenario == .beforeBedBreathe ? now.addingTimeInterval(150) : nil
          ) {}
        default:
          TimelineView(.periodic(from: .now, by: 1)) { tick in DoorSheet(model: app, now: tick.date)
          }
        }
      }
    }
  }
#endif
