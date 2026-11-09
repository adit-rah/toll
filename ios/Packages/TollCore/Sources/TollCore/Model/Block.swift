import Foundation

/// What the extensions need to know about a block: which app refs it shields and when. The block name
/// and the tokens themselves stay in the app (names in the store, tokens in `TokenRegistry`).
public struct BlockDefinition: Codable, Hashable, Sendable, Identifiable {
  public var id: BlockRef
  public var appRefs: [AppRef]
  public var schedule: Schedule

  public init(id: BlockRef, appRefs: [AppRef], schedule: Schedule) {
    self.id = id
    self.appRefs = appRefs
    self.schedule = schedule
  }

  /// The DeviceActivity name for this block's schedule window.
  public var activityName: String { "block.\(id.rawValue)" }
}

/// A session after a pass (G-6): the unlocked apps, the minutes chosen, and the hard expiry that is the
/// truth when callbacks are late or missing.
public struct ActiveSession: Codable, Hashable, Sendable, Identifiable {
  public var id: UUID
  public var appRefs: [AppRef]
  public var minutes: Int
  public var startedAt: Date
  public var expiresAt: Date

  public init(
    id: UUID = UUID(), appRefs: [AppRef], minutes: Int, startedAt: Date, windowMinutes: Int
  ) {
    self.id = id
    self.appRefs = appRefs
    self.minutes = minutes
    self.startedAt = startedAt
    expiresAt = startedAt.addingTimeInterval(TimeInterval(windowMinutes * 60))
  }

  public var activityName: String { "session.\(id.uuidString.lowercased())" }

  public func isExpired(at date: Date) -> Bool { date >= expiresAt }
}
