#if DEBUG
  import SwiftUI
  import TollCore
  import TollData
  import TollScreenTime
  import TollUI

  /// Debug builds open straight into a screen with `-TollDemo <scenario>` (docs/renders.md). Release
  /// builds contain none of this.
  enum DemoScenario: String, CaseIterable {
    case empty, welcome, wake, home, permissions, always, blocklist, ready
    case wakeWeekends = "wake-weekends"
    case permissionsDenied = "permissions-denied"
    case locationOff = "location-off"
    case readyAnywhere = "ready-anywhere"
    case homeEvening = "home-evening"
    case homeBlocked = "home-blocked"
    case homeAway = "home-away"
    case homeFirstWeek = "home-first-week"
    case homeLastNight = "home-last-night"
    case homeWeek = "home-week"
    case homePaused = "home-paused"
    case homeLocation = "home-location"
    case purchase, settings, insights
    case purchasePending = "purchase-pending"
    case purchaseFailed = "purchase-failed"
    case purchaseRestoreNone = "purchase-restore-none"
    case blocks
    case blockNew = "block-new"
    case blockEdit = "block-edit"
    case doorChoosing = "door-choosing"
    case doorWaiting = "door-waiting"
    case doorOpen = "door-open"
    case doorNone = "door-none"

    static var current: DemoScenario? {
      UserDefaults.standard.string(forKey: "TollDemo").flatMap(Self.init(rawValue:))
    }

    var setupPath: [SetupModel.Step]? {
      switch self {
      case .welcome: []
      case .wake, .wakeWeekends: [.wake]
      case .home: [.wake, .home]
      case .permissions, .permissionsDenied: [.wake, .home, .permissions]
      case .always: [.wake, .home, .permissions, .always]
      case .locationOff: [.wake, .home, .permissions, .always, .locationOff]
      case .blocklist: [.wake, .home, .permissions, .blocklist]
      case .ready, .readyAnywhere: [.wake, .home, .permissions, .blocklist, .ready]
      default: nil
      }
    }

    /// The simulator cannot grant Family Controls or answer the location prompt; each screen past
    /// them assumes the answers its board shows.
    var screenTime: ScreenTimeAuthorization.State? {
      switch self {
      case .blocklist, .ready, .readyAnywhere, .always, .locationOff: .approved
      case .permissionsDenied: .denied
      default: nil
      }
    }

    var location: LocationAccess.State? {
      switch self {
      case .blocklist, .ready, .permissionsDenied: .always
      case .always, .locationOff, .readyAnywhere: .whileUsing
      default: nil
      }
    }
    var isDoor: Bool { rawValue.hasPrefix("door") }
    /// Screens Home pushes rather than presents, with the screens under them.
    var routes: [HomeRoute] {
      switch self {
      case .insights: [.insights]
      case .settings: [.settings]
      case .blocks: [.blocks]
      case .blockNew: [.blocks, .block(nil)]
      case .blockEdit: [.blocks, .block(BlockID("study"))]
      default: []
      }
    }
    var isHome: Bool {
      rawValue.hasPrefix("home-") || rawValue.hasPrefix("block") || isDoor
        || rawValue.hasPrefix("purchase") || [.settings, .insights].contains(self)
    }
  }

  struct DemoRoot: View {
    let app: AppModel
    let scenario: DemoScenario

    var body: some View {
      if let path = scenario.setupPath {
        DemoSetup(app: app, path: path)
      } else if scenario.isHome {
        DemoHome(app: app, scenario: scenario)
      } else {
        TollColor.bg.ignoresSafeArea()
      }
    }
  }

  /// Home in one of its states, with the door or the purchase sheet over it where the scenario says.
  private struct DemoHome: View {
    let app: AppModel
    let scenario: DemoScenario
    let now = Date()

    var body: some View {
      let fixture = DemoFixture(scenario: scenario, now: now)
      let home = HomeSnapshot(state: fixture.state, log: fixture.log, now: now, calendar: .current)
      NavigationStack(path: .constant(scenario.routes)) {
        HomeView(
          home: home, price: Copy.fallbackPrice, openSettings: {}, openDoor: {}, openPurchase: {},
          fixLocation: {}, openBlock: { _ in }, openInsights: {}
        )
        .homeNavigation()
        .navigationDestination(for: HomeRoute.self) { route in
          if route == .insights {
            InsightsView(log: fixture.log)
          } else {
            HomeDestination(model: app, route: route) {}
          }
        }
      }
      .tint(TollColor.accent)
      .sheet(
        isPresented: .constant(!scenario.rawValue.hasPrefix("home-") && scenario.routes.isEmpty)
      ) {
        switch scenario {
        case .purchase: PurchaseSheet(model: app, home: home)
        case .purchasePending: PurchaseSheet(model: app, home: home, outcome: .pending)
        case .purchaseFailed: PurchaseSheet(model: app, home: home, outcome: .failed)
        case .purchaseRestoreNone:
          PurchaseSheet(model: app, home: home, outcome: .nothingToRestore)
        default:
          TimelineView(.periodic(from: .now, by: 1)) { tick in DoorSheet(model: app, now: tick.date)
          }
        }
      }
      .task { app.show(fixture.state) }
    }
  }

  private struct DemoSetup: View {
    @State private var model: SetupModel

    init(app: AppModel, path: [SetupModel.Step]) {
      let model = SetupModel(app: app, path: path)
      model.placesHome = false
      model.home = Place(
        name: Copy.Setup.homeName, latitude: 51.5246, longitude: -0.0786, radiusMeters: 150)
      _model = State(initialValue: model)
    }

    var body: some View {
      SetupFlowContent(model: model)
        .task {
          let scenario = DemoScenario.current
          ScreenTimeAuthorization.simulated = scenario?.screenTime
          LocationAccess.simulated = scenario?.location
          model.weekendsDiffer = scenario == .wakeWeekends
          model.app.readPermissions()
        }
    }
  }
#endif
