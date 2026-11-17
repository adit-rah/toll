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
      }
    }

    /// The simulator cannot grant Family Controls; screens past the permission step assume it.
    var screenTimeApproved: Bool { self == .keepOpen || self == .ready }
  }

  struct DemoRoot: View {
    let app: AppModel
    let scenario: DemoScenario

    var body: some View {
      if let path = scenario.setupPath {
        DemoSetup(app: app, path: path)
      } else {
        TollColor.bg.ignoresSafeArea()
      }
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
