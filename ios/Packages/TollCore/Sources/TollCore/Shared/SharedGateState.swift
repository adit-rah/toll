import Foundation

/// The gate state every process needs: blocks and their schedules, live sessions, the running wait, and
/// what the shield text shows. The app owns it; the monitor removes ended sessions; the shield extensions
/// only read it.
public struct SharedGateState: Codable, Equatable, Sendable {
  public var blocks: [BlockDefinition] = []
  public var sessions: [ActiveSession] = []
  public var wait: Wait?
  /// The latest "Open Toll" tap not yet acted on; Toll enters the gate for it only when opened by the
  /// user within `gate.resumeWindow` (G-3), never from a background wake.
  public var pendingHit: PendingHit?
  /// A pass granted but not yet used: the session picker is showing, or the pass was set aside. It
  /// becomes a `pass` event only when a session starts (G-6, G-7).
  public var pendingPass: PendingPass?
  public var resetHour = TollConfig.defaults.gate.dayResetHour
  public var notificationsAllowed = false
  /// Passes per app today, for "You've unblocked this 2 times today." (spec §10).
  public var unblocksDay: TollDay?
  public var unblocks: [AppRef: Int] = [:]
  public var lastSessionMinutes: Int?

  public init() {}

  public func unblocks(of appRef: AppRef, on day: TollDay) -> Int {
    unblocksDay == day ? unblocks[appRef, default: 0] : 0
  }
}

public struct PendingHit: Codable, Hashable, Sendable {
  public var appRef: AppRef
  public var at: Date

  public init(appRef: AppRef, at: Date) {
    self.appRef = appRef
    self.at = at
  }
}

public struct PendingPass: Codable, Hashable, Sendable {
  /// Where the request came from: a shield hit, or Unblock inside Toll.
  public enum Origin: String, Codable, Sendable {
    case shield, app
  }

  public var appRefs: [AppRef]
  public var free: Bool
  public var waitMinutes: Int
  public var grantedAt: Date
  public var origin: Origin
  public var blockRef: BlockRef?
  /// Set aside with "Not now": kept for the day, but the session picker stays off screen until the
  /// next shield hit or an explicit resume.
  public var deferred: Bool

  public init(
    appRefs: [AppRef], free: Bool, waitMinutes: Int, grantedAt: Date, origin: Origin = .shield,
    blockRef: BlockRef? = nil, deferred: Bool = false
  ) {
    self.appRefs = appRefs
    self.free = free
    self.waitMinutes = waitMinutes
    self.grantedAt = grantedAt
    self.origin = origin
    self.blockRef = blockRef
    self.deferred = deferred
  }

  // State written before passes had an origin has neither key; such a pass came from a shield.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    appRefs = try container.decode([AppRef].self, forKey: .appRefs)
    free = try container.decode(Bool.self, forKey: .free)
    waitMinutes = try container.decode(Int.self, forKey: .waitMinutes)
    grantedAt = try container.decode(Date.self, forKey: .grantedAt)
    origin = try container.decodeIfPresent(Origin.self, forKey: .origin) ?? .shield
    blockRef = try container.decodeIfPresent(BlockRef.self, forKey: .blockRef)
    deferred = try container.decodeIfPresent(Bool.self, forKey: .deferred) ?? false
  }
}

extension AppRef: CodingKeyRepresentable {
  public var codingKey: CodingKey { AnyCodingKey(rawValue) }
  public init?<T: CodingKey>(codingKey: T) { self.init(rawValue: codingKey.stringValue) }
}

struct AnyCodingKey: CodingKey {
  var stringValue: String
  var intValue: Int? { nil }
  init(_ value: String) { stringValue = value }
  init?(stringValue: String) { self.stringValue = stringValue }
  init?(intValue: Int) { nil }
}

public struct SharedGateStore: Sendable {
  public let url: URL

  public init(url: URL = AppGroup.file("gate-state.json")) {
    self.url = url
  }

  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .millisecondsSince1970
    return encoder
  }()

  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    return decoder
  }()

  public func load() -> SharedGateState {
    guard let data = CoordinatedFile.read(url) else { return SharedGateState() }
    return (try? Self.decoder.decode(SharedGateState.self, from: data)) ?? SharedGateState()
  }

  @discardableResult
  public func update(_ change: (inout SharedGateState) -> Void) -> SharedGateState {
    var result = SharedGateState()
    CoordinatedFile.update(url) { data in
      let stored = data.flatMap { try? Self.decoder.decode(SharedGateState.self, from: $0) }
      var state = stored ?? SharedGateState()
      change(&state)
      result = state
      // Most calls find nothing to change (every second of a wait, every reconcile); the file is left
      // alone then instead of being rewritten under coordination each time.
      if state == stored { return nil }
      return try? Self.encoder.encode(state)
    }
    return result
  }
}
