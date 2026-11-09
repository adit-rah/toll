import Foundation
import Sentry
import TelemetryDeck

/// Our own instrumentation (spec §16): at most ten anonymous events, no ids, no tags, no timestamps.
public enum AnalyticsEvent: Sendable {
  case appOpen
  case onboardingStep(step: String, skipped: Bool)
  case screenTimeAuth(granted: Bool)
  case blockAdded
  case blockRemoved
  case gateEntered(free: Bool)
  case waitAbandoned
  case friendAdded(source: String)
  case shareCard(type: String, format: String)
  case accountDeleted

  var name: String {
    switch self {
    case .appOpen: "app_open"
    case .onboardingStep: "onboarding_step"
    case .screenTimeAuth: "screen_time_auth"
    case .blockAdded: "block_added"
    case .blockRemoved: "block_removed"
    case .gateEntered: "gate_entered"
    case .waitAbandoned: "wait_abandoned"
    case .friendAdded: "friend_added"
    case .shareCard: "share_card"
    case .accountDeleted: "account_deleted"
    }
  }

  var parameters: [String: String] {
    switch self {
    case .onboardingStep(let step, let skipped): ["step": step, "skipped": String(skipped)]
    case .screenTimeAuth(let granted): ["result": granted ? "granted" : "denied"]
    case .gateEntered(let free): ["path": free ? "free" : "waited"]
    case .friendAdded(let source): ["source": source]
    case .shareCard(let type, let format): ["type": type, "format": format]
    default: [:]
    }
  }
}

public struct Analytics: Sendable {
  let enabled: Bool

  public static let disabled = Analytics(enabled: false)

  /// IDs come from Info.plist (`TollTelemetryDeckAppID`, `TollSentryDSN`); empty means off.
  @MainActor
  public static func live() -> Analytics {
    let info = Bundle.main.infoDictionary ?? [:]
    if let dsn = info["TollSentryDSN"] as? String, !dsn.isEmpty {
      SentrySDK.start { options in
        options.dsn = dsn
        options.sendDefaultPii = false
        options.tracesSampleRate = 0
      }
    }
    guard let appID = info["TollTelemetryDeckAppID"] as? String, !appID.isEmpty else {
      return .disabled
    }
    TelemetryDeck.initialize(config: .init(appID: appID))
    return Analytics(enabled: true)
  }

  public func send(_ event: AnalyticsEvent) {
    guard enabled else { return }
    TelemetryDeck.signal(event.name, parameters: event.parameters)
  }
}
