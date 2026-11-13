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

  /// The scenario comes from the launch argument `-TollDemo <scenario>`. The session token and API base
  /// URL come from the environment (`TOLL_DEMO_TOKEN`, `TOLL_DEMO_API`): a base64url token can start with
  /// `-`, which launch-argument parsing would read as another flag and drop.
  struct DemoLaunch: Sendable {
    let scenario: DemoScenario
    let token: String?
    let apiBaseURL: URL?

    static func fromLaunch(
      defaults: UserDefaults = .standard,
      environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DemoLaunch? {
      guard let name = defaults.string(forKey: "TollDemo") else { return nil }
      guard let scenario = DemoScenario(rawValue: name) else {
        Logger(subsystem: "com.advan.toll", category: "demo").error(
          "unknown scenario \(name, privacy: .public)")
        return nil
      }
      return DemoLaunch(
        scenario: scenario, token: environment["TOLL_DEMO_TOKEN"].flatMap { $0.isEmpty ? nil : $0 },
        apiBaseURL: environment["TOLL_DEMO_API"].flatMap(URL.init(string:)))
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
