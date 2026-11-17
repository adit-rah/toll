#if DEBUG
  import SwiftUI
  import TollCore
  import TollScreenTime
  import TollUI

  /// Debug builds open straight into a screen with `-TollDemo <scenario>` (docs/renders.md). Release
  /// builds contain none of this.
  enum DemoScenario: String, CaseIterable {
    case empty, welcome, wake, home, permissions
    case keepOpen = "keep-open"
    case ready
    case statusBlocked = "status-blocked"
    case statusStarts = "status-starts"
    case statusAway = "status-away"
    case doorChoosing = "door-choosing"
    case doorWaiting = "door-waiting"
    case doorOpen = "door-open"
    case doorNone = "door-none"

    static var current: DemoScenario? {
      UserDefaults.standard.string(forKey: "TollDemo").flatMap(Self.init(rawValue:))
    }

    var setupPath: [SetupModel.Step]? {
      switch self {
      case .empty: nil
      case .welcome: []
      case .wake: [.wake]
      case .home: [.wake, .home]
      case .permissions: [.wake, .home, .permissions]
      case .keepOpen: [.wake, .home, .permissions, .keepOpen]
      case .ready: [.wake, .home, .permissions, .keepOpen, .ready]
      default: nil
      }
    }

    /// A state built around the current time, so the line reads the same whenever it is rendered.
    func status(now: Date) -> SleepState? {
      let calendar = Calendar.current
      let minute =
        calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
      var state = SleepState()
      state.presence = Presence(isHome: self != .statusAway, at: now)
      switch self {
      case .statusBlocked, .doorChoosing, .doorWaiting, .doorOpen, .doorNone:
        state.settings.window = SleepWindow(
          start: ClockTime(hour: minute / 60).adding(minutes: -60), end: ClockTime(hour: 7))
        state.blockOn = true
        state.blockEndsAt = calendar.date(byAdding: .hour, value: 8, to: now)
        state.doorAskedAt = isDoor ? now : nil
        if self == .doorNone { state.unlocks.spent = 3 }
        if self == .doorWaiting || self == .doorOpen {
          state.unlocks.spent = 1
          var door = Door(
            app: Data(), waitEndsAt: now.addingTimeInterval(self == .doorWaiting ? 90 : -30))
          if self == .doorOpen { door.openedAt = now.addingTimeInterval(-30) }
          state.door = door
        } else if self != .doorNone {
          state.unlocks.spent = 1
          state.unlocks.cleanNights = 3
        }
      case .statusStarts:
        state.settings.window = SleepWindow(
          start: ClockTime(hour: 22, minute: 30), end: ClockTime(hour: 7))
        if (22 * 60 + 30...1439).contains(minute) || minute < 7 * 60 {
          state.settings.window = SleepWindow(start: ClockTime(hour: 12), end: ClockTime(hour: 13))
        }
      case .statusAway:
        let start = ClockTime(hour: minute / 60)
        state.settings.window = SleepWindow(start: start, end: start.adding(minutes: 8 * 60))
      default:
        return nil
      }
      return state
    }

    var isDoor: Bool { rawValue.hasPrefix("door") }

    /// The simulator cannot grant Family Controls; screens past the permission step assume it.
    var screenTimeApproved: Bool { self == .keepOpen || self == .ready }
  }

  struct DemoRoot: View {
    let app: AppModel
    let scenario: DemoScenario

    var body: some View {
      if let path = scenario.setupPath {
        DemoSetup(app: app, path: path)
      } else if let state = scenario.status(now: Date()) {
        if scenario.isDoor {
          DemoDoor(app: app, state: state)
        } else {
          StatusView(state: state, now: Date(), openSettings: {})
        }
      } else {
        TollColor.bg.ignoresSafeArea()
      }
    }
  }

  /// Status with the door sheet over it, as after "Open" on the block screen.
  private struct DemoDoor: View {
    let app: AppModel
    let state: SleepState

    var body: some View {
      StatusView(state: state, now: Date(), openSettings: {})
        .sheet(isPresented: .constant(true)) {
          TimelineView(.periodic(from: .now, by: 1)) { tick in
            DoorSheet(model: app, now: tick.date)
          }
        }
        .task { app.show(state) }
    }
  }

  private struct DemoSetup: View {
    @State private var model: SetupModel

    init(app: AppModel, path: [SetupModel.Step]) {
      let model = SetupModel(app: app, path: path)
      model.placesHome = false
      model.home = HomePoint(latitude: 51.5246, longitude: -0.0786, radiusMeters: 150)
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
