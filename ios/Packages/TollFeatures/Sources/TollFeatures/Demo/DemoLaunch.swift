#if DEBUG
  import Foundation
  import OSLog
  import TollCore
  import TollData
  import TollScreenTime

  /// One screen state to open straight into, with seeded data, so a simulator can be screenshotted
  /// without setup taps or Screen Time (docs/renders.md). Debug builds only; Release never sees it.
  enum DemoScenario: String, CaseIterable, Sendable {
    case welcome
    case permissions
    case setupBlocks = "setup-blocks"
    case soloHome = "solo-home"
    case home, insights, people, gate
    case screenTimeOff = "screen-time-off"

    var signedIn: Bool {
      switch self {
      case .home, .insights, .people, .gate, .screenTimeOff: true
      default: false
      }
    }

    var choseSolo: Bool { [.permissions, .setupBlocks, .soloHome].contains(self) }
    var hasBlocks: Bool { signedIn || self == .soloHome }

    var screenTime: ScreenTimeAuthorization.State {
      switch self {
      case .welcome, .permissions: .notDetermined
      case .screenTimeOff: .denied
      default: .approved
      }
    }

    var tab: AppTab {
      switch self {
      case .insights: .insights
      case .people: .people
      default: .home
      }
    }
  }

  /// Read from launch arguments: `-TollDemo <scenario>`, plus `-TollDemoToken <session token>` and
  /// `-TollDemoAPI <base URL>` for the signed-in scenarios, which talk to a local Worker.
  struct DemoLaunch: Sendable {
    let scenario: DemoScenario
    let token: String?
    let apiBaseURL: URL?

    static func fromArguments(_ defaults: UserDefaults = .standard) -> DemoLaunch? {
      guard let name = defaults.string(forKey: "TollDemo") else { return nil }
      guard let scenario = DemoScenario(rawValue: name) else {
        Logger(subsystem: "com.advan.toll", category: "demo").error(
          "unknown scenario \(name, privacy: .public)")
        return nil
      }
      return DemoLaunch(
        scenario: scenario, token: defaults.string(forKey: "TollDemoToken"),
        apiBaseURL: defaults.string(forKey: "TollDemoAPI").flatMap(URL.init(string:)))
    }

    @MainActor
    func makeModel() throws -> AppModel {
      let deps =
        try apiBaseURL.map { try Dependencies.preview(apiBaseURL: $0) } ?? Dependencies.preview()
      ScreenTimeAuthorization.simulated = scenario.screenTime
      let model = AppModel(deps: deps)
      model.tab = scenario.tab
      model.beforeLaunch = { [self] in await DemoSeed(deps: deps).run(self) }
      return model
    }
  }
#endif
