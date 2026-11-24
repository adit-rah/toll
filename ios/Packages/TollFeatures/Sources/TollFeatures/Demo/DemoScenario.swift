#if DEBUG
  import SwiftUI
  import TollCore
  import TollData
  import TollScreenTime
  import TollUI

  /// Debug builds open straight into a screen with `-TollDemo <scenario>` (docs/renders.md). Release
  /// builds contain none of this.
  enum DemoScenario: String, CaseIterable {
    case empty, welcome, wake, blocklist, ready
    case wakeWeekends = "wake-weekends"
    case screenTime = "screen-time"
    case screenTimeAllowed = "screen-time-allowed"
    case screenTimeDenied = "screen-time-denied"
    /// "Only when I'm home" (D68): a sheet over Tonight, home not set yet.
    case setHome = "set-home"
    case setHomeOff = "set-home-off"
    case setHomeLocation = "set-home-location"
    case setHomeAlways = "set-home-always"
    case setHomeLocationOff = "set-home-location-off"
    case homeEvening = "home-evening"
    case homeBlocked = "home-blocked"
    case homeAway = "home-away"
    case homeFirstWeek = "home-first-week"
    case homeLastNight = "home-last-night"
    case homeWeek = "home-week"
    case homePaused = "home-paused"
    case homeLocation = "home-location"
    case homeScreenTimeOff = "home-screen-time-off"
    case homeNoBlocks = "home-no-blocks"
    case homeMorning = "home-morning"
    case homeMorningGap = "home-morning-gap"
    case homeMorningAway = "home-morning-away"
    /// A weekday at 11 am with Study on: Tonight's one quiet line about it (D68, #89), and Study and
    /// Gym on the day's strip (D75).
    case homeDay = "home-day"
    /// The strip's snippet open (D75): on the night in the evening, and on Study at 11 am.
    case homeStripNight = "home-strip-night"
    case homeStripDay = "home-strip-day"
    case sleepMonday = "sleep-monday"
    case sleepBest = "sleep-best"
    /// Home not set (D68): the first evening, then the card the morning after the first night.
    case homeAnywhere = "home-anywhere"
    case homeCard = "home-card"
    /// The heads-up card (#104): home set, the evening after the first night, iOS not asked yet.
    case homeHeadsUp = "home-heads-up"
    case purchase, settings, insights
    case settingsAnywhere = "settings-anywhere"
    /// Settings with notifications denied: the heads-up row leaves for iOS Settings (#104).
    case settingsHeadsUpDenied = "settings-heads-up-denied"
    case purchasePending = "purchase-pending"
    case purchaseFailed = "purchase-failed"
    case purchaseRestoreNone = "purchase-restore-none"
    case purchaseDone = "purchase-done"
    case blocks
    /// Blocks on a weekday at 11 am, Study on (#89).
    case blocksDay = "blocks-day"
    /// New block: the kinds, then (`-gym`) Gym picked with its hours and no apps yet (#89).
    case blockNew = "block-new"
    case blockNewGym = "block-new-gym"
    case blockEdit = "block-edit"
    /// Editing Study while it's on, and editing the night (#89).
    case blockEditOn = "block-edit-on"
    case blockNight = "block-night"
    case doorChoosing = "door-choosing"
    case doorWaiting = "door-waiting"
    case doorOpen = "door-open"
    case doorNone = "door-none"

    static var current: DemoScenario? {
      UserDefaults.standard.string(forKey: "TollDemo").flatMap(Self.init(rawValue:))
    }

    /// `-TollWordless YES`: the wordless test's renders (docs/design.md §5).
    static var wordless: Bool { UserDefaults.standard.bool(forKey: "TollWordless") }

    var setupPath: [SetupModel.Step]? {
      switch self {
      case .welcome: []
      case .wake, .wakeWeekends: [.wake]
      case .screenTime, .screenTimeAllowed, .screenTimeDenied: [.wake, .screenTime]
      case .blocklist: [.wake, .screenTime, .blocklist]
      case .ready: [.wake, .screenTime, .blocklist, .ready]
      default: nil
      }
    }

    /// The set-home sheet's screens under the map.
    var setHomePath: [SetHomeModel.Step]? {
      switch self {
      case .setHome, .setHomeOff: []
      case .setHomeLocation: [.location]
      case .setHomeAlways: [.location, .always]
      case .setHomeLocationOff: [.location, .locationOff]
      default: nil
      }
    }

    /// Home not set yet (D68): onboarding's Sleep block has no place.
    var homeNotSet: Bool {
      setHomePath != nil || [.homeAnywhere, .homeCard, .settingsAnywhere].contains(self)
    }

    /// The simulator cannot grant Family Controls or answer the location prompt; each screen past
    /// them assumes the answers its board shows. Onboarding never asks for location (D68).
    var screenTime: ScreenTimeAuthorization.State? {
      switch self {
      case .blocklist, .ready, .screenTimeAllowed: .approved
      case .screenTimeDenied, .homeScreenTimeOff: .denied
      // Every screen after setup assumes what its board shows: everything working.
      default: isHome ? .approved : nil
      }
    }

    var location: LocationAccess.State? {
      switch self {
      case .setHome, .setHomeLocation, .setHomeAlways, .homeLocation: .whileUsing
      case .setHomeOff: .denied
      case .setHomeLocationOff: .approximate
      case .homeAnywhere, .homeCard, .settingsAnywhere: .notDetermined
      default: isHome ? .always : nil
      }
    }
    /// Every screen after setup assumes the heads-up is allowed, unless it shows the asking.
    var notifications: NotificationPermission? {
      switch self {
      case .homeHeadsUp: .notAsked
      case .settingsHeadsUpDenied: .denied
      default: isHome ? .allowed : nil
      }
    }
    var isDoor: Bool { rawValue.hasPrefix("door") }
    /// The tab the screen is on (D63).
    var tab: DuskTab {
      switch self {
      case .insights, .sleepMonday, .sleepBest: .sleep
      case .blocks, .blocksDay, .blockNew, .blockNewGym, .blockEdit, .blockEditOn, .blockNight:
        .blocks
      default: .tonight
      }
    }
    /// The kind a new-block scenario shows already picked.
    var newBlockKind: Block.Kind? { self == .blockNewGym ? .gym : nil }
    /// Weekday scenarios at 11 am, with Study on.
    var isDay: Bool { [.homeDay, .homeStripDay, .blocksDay, .blockEditOn].contains(self) }
    /// The block whose snippet the strip opens on (D75).
    var snippet: BlockID? {
      switch self {
      case .homeStripNight: BlockID("sleep")
      case .homeStripDay: BlockID("study")
      default: nil
      }
    }
    /// Screens pushed on the tab's stack, with the screens under them.
    var routes: [HomeRoute] {
      switch self {
      case .settings, .settingsAnywhere, .settingsHeadsUpDenied: [.settings]
      case .blockNew, .blockNewGym: [.block(nil)]
      case .blockEdit, .blockEditOn: [.block(BlockID("study"))]
      case .blockNight: [.block(BlockID("sleep"))]
      default: []
      }
    }
    /// The door and the purchase are sheets over Tonight.
    var presentsSheet: Bool { isDoor || rawValue.hasPrefix("purchase") || setHomePath != nil }
    var isHome: Bool {
      rawValue.hasPrefix("home-") || rawValue.hasPrefix("sleep-") || rawValue.hasPrefix("block")
        || isDoor || rawValue.hasPrefix("purchase") || rawValue.hasPrefix("settings")
        || setHomePath != nil || self == .insights
    }
  }

  struct DemoRoot: View {
    let app: AppModel
    let scenario: DemoScenario

    var body: some View {
      Group {
        if let path = scenario.setupPath {
          DemoSetup(app: app, path: path)
        } else if scenario.isHome {
          DemoHome(app: app, scenario: scenario)
        } else {
          TollColor.bg.ignoresSafeArea()
        }
      }
      .environment(\.tollWordless, DemoScenario.wordless)
    }
  }

  /// Home in one of its states, with the door or the purchase sheet over it where the scenario says.
  private struct DemoHome: View {
    let app: AppModel
    let scenario: DemoScenario
    /// The purchase sheet from the pill, so a scripted tap on it opens what the app's does (D75).
    @State private var buying = false

    var body: some View {
      let now = DemoClock.now(for: scenario)
      let fixture = DemoFixture(scenario: scenario, now: now)
      let home = HomeSnapshot(
        state: fixture.state, log: fixture.log, now: now, calendar: .current,
        screenTime: scenario != .homeScreenTimeOff,
        notifications: scenario.notifications ?? .allowed)
      DuskTabs(
        tab: .constant(scenario.tab),
        tonightPath: .constant(scenario.tab == .tonight ? scenario.routes : []),
        blocksPath: .constant(scenario.tab == .blocks ? scenario.routes : []), model: app,
        sleep: YourSleep(
          state: fixture.state, log: fixture.log, history: fixture.history, now: now,
          calendar: .current),
        log: fixture.log, openPurchase: {}
      ) {
        HomeView(
          home: home, price: Copy.fallbackPrice, openSettings: {}, openDoor: {},
          openPurchase: { buying = true }, fixLocation: {}, snippet: scenario.snippet
        )
        .sheet(isPresented: $buying) { PurchaseSheet(model: app, home: home) }
      }
      .sheet(isPresented: .constant(scenario.presentsSheet)) {
        switch scenario {
        case .purchase: PurchaseSheet(model: app, home: home)
        case .purchasePending: PurchaseSheet(model: app, home: home, outcome: .pending)
        case .purchaseFailed: PurchaseSheet(model: app, home: home, outcome: .failed)
        case .purchaseRestoreNone:
          PurchaseSheet(model: app, home: home, outcome: .nothingToRestore)
        case .purchaseDone: PurchaseSheet(model: app, home: home, outcome: .purchased)
        case _ where scenario.setHomePath != nil:
          DemoSetHome(app: app, path: scenario.setHomePath ?? [])
        default:
          TimelineView(.periodic(from: .now, by: 1)) { tick in DoorSheet(model: app, now: tick.date)
          }
        }
      }
    }
  }

  private struct DemoSetup: View {
    @State private var model: SetupModel

    init(app: AppModel, path: [SetupModel.Step]) {
      _model = State(initialValue: SetupModel(app: app, path: path))
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

  /// The set-home sheet with home placed in London: the simulator has no one to answer the prompt.
  private struct DemoSetHome: View {
    @State private var model: SetHomeModel

    init(app: AppModel, path: [SetHomeModel.Step]) {
      let model = SetHomeModel(app: app, path: path)
      model.placesHome = false
      if !model.mapBlocked {
        model.home = Place(
          name: Copy.Setup.homeName, latitude: 51.5246, longitude: -0.0786, radiusMeters: 150)
      }
      _model = State(initialValue: model)
    }

    var body: some View {
      SetHomeFlowContent(model: model)
    }
  }
#endif
