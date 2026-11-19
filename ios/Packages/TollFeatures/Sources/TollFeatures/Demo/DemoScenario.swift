#if DEBUG
  import SwiftUI
  import TollCore
  import TollScreenTime
  import TollUI

  /// Debug builds open straight into a screen with `-TollDemo <scenario>` (docs/renders.md). Release
  /// builds contain none of this.
  enum DemoScenario: String, CaseIterable {
    case empty, welcome, wake, home, permissions, always, blocklist, ready
    case homeEvening = "home-evening"
    case homeBlocked = "home-blocked"
    case homeAway = "home-away"
    case homeFirstWeek = "home-first-week"
    case homeLastNight = "home-last-night"
    case homePaused = "home-paused"
    case homeLocation = "home-location"
    case purchase, settings
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
      case .wake: [.wake]
      case .home: [.wake, .home]
      case .permissions: [.wake, .home, .permissions]
      case .always: [.wake, .home, .permissions, .always]
      case .blocklist: [.wake, .home, .permissions, .blocklist]
      case .ready: [.wake, .home, .permissions, .blocklist, .ready]
      default: nil
      }
    }

    /// The simulator cannot grant Family Controls; screens past the permission step assume it.
    var screenTimeApproved: Bool { self == .blocklist || self == .ready }
    var isDoor: Bool { rawValue.hasPrefix("door") }
    var isHome: Bool {
      rawValue.hasPrefix("home-") || rawValue.hasPrefix("block") || isDoor
        || [.purchase, .settings].contains(self)
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
      HomeView(
        home: home, price: Copy.fallbackPrice, openSettings: {}, openDoor: {}, openPurchase: {},
        fixLocation: {}
      )
      .sheet(isPresented: .constant(!scenario.rawValue.hasPrefix("home-"))) {
        switch scenario {
        case .purchase: PurchaseSheet(model: app, home: home)
        case .settings: SettingsView(model: app)
        case .blocks: NavigationStack { BlocksView(model: app) }
        case .blockNew: BlockEditorView(app: app, editing: nil)
        case .blockEdit: BlockEditorView(app: app, editing: BlockID("study"))
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
          if DemoScenario.current?.screenTimeApproved == true {
            ScreenTimeAuthorization.simulated = .approved
            model.app.readPermissions()
          }
        }
    }
  }
#endif
