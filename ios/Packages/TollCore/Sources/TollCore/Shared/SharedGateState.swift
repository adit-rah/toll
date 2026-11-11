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
  /// A pass granted but not yet turned into a session: the session picker is showing (G-3, G-6).
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
  public var appRefs: [AppRef]
  public var free: Bool
  public var waitMinutes: Int
  public var grantedAt: Date

  public init(appRefs: [AppRef], free: Bool, waitMinutes: Int, grantedAt: Date) {
    self.appRefs = appRefs
    self.free = free
    self.waitMinutes = waitMinutes
    self.grantedAt = grantedAt
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
