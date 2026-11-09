import Foundation
import TollCore

// Wire types mirroring the Zod schemas in api/src/features/*/contract.ts. Times are epoch milliseconds;
// days and weeks are "YYYY-MM-DD".

public typealias Millis = Double

extension Date {
  public init(millis: Millis) { self.init(timeIntervalSince1970: millis / 1000) }
  public var millis: Millis { (timeIntervalSince1970 * 1000).rounded() }
}

public struct PersonRef: Codable, Hashable, Sendable, Identifiable {
  public var id: String
  public var displayName: String
  public var handle: String
  public var photoUrl: String?
}

public struct PassLine: Codable, Hashable, Sendable {
  public var at: Millis
  public var tzOffset: Int
  public var tag: Tag?
  public var free: Bool
  public var waitMinutes: Int
}

public struct WeekStats: Codable, Hashable, Sendable {
  public var passes: Int
  public var lastWeek: Int
  public var trend: Double?
  public var cleanDays: Int
  public var hits: Int
  public var held: Int
  public var waited: Int
  public var waitMinutes: Int

  public var heldPercent: Int? {
    hits == 0 ? nil : Int((Double(held) / Double(hits) * 100).rounded())
  }
}

public struct FriendSummary: Codable, Hashable, Sendable, Identifiable {
  public struct Today: Codable, Hashable, Sendable {
    public var passes: Int
    public var level: Int?
  }

  public struct BlockSummary: Codable, Hashable, Sendable {
    public var tags: [Tag?]
    public var schedule: Schedule
  }

  public var user: PersonRef
  public var today: Today
  public var week: WeekStats
  public var silentSince: String?
  public var latestPass: PassLine?
  public var todayPasses: [PassLine]
  public var yesterdayPasses: [PassLine]
  public var blocks: [BlockSummary]
  public var friendsSince: Millis

  public var id: String { user.id }
  public var level: StatusLevel? { today.level.flatMap(StatusLevel.init(rawValue:)) }
}

public struct Pinned: Codable, Hashable, Sendable {
  public enum Kind: String, Codable, Sendable { case removal, loosened, silence }
  public var kind: Kind
  public var user: PersonRef
  public var tags: [Tag?]
  public var schedule: Schedule?
  public var since: Millis
}

public struct HomeResponse: Codable, Hashable, Sendable {
  public var friends: [FriendSummary]
  public var pinned: [Pinned]
  public var friendsHeldPercent: Int?
  public var pendingRequests: Int
  public var asOf: Millis
}

public struct SchoolRef: Codable, Hashable, Sendable {
  public var id: Int
  public var name: String
}

public struct Me: Codable, Hashable, Sendable {
  public var id: String
  public var displayName: String?
  public var handle: String?
  public var photoUrl: String?
  public var email: String?
  public var discoverable: Bool
  public var timezone: String
  public var notifyEnabled: Bool
  public var notifyHour: Int?
  public var handleChangedAt: Millis?
  public var school: SchoolRef?
  public var inviteCode: String
  public var createdAt: Millis

  public var hasIdentity: Bool { handle != nil && displayName != nil }
}

public struct AuthSession: Codable, Sendable {
  public var token: String
  public var user: Me
  public var isNew: Bool
}

/// The event wire shape (`POST /v1/events`).
struct EventWire: Codable, Sendable {
  var id: String
  var type: String
  var occurredAt: Millis
  var tzOffset: Int
  var appRef: String?
  var blockRef: String?
  var appRefs: [String]?
  var via: String?
  var free: Bool?
  var waitMinutes: Int?
  var sessionMinutes: Int?
  var schedule: Schedule?
  var oldSchedule: Schedule?

  init(_ e: GateEvent) {
    id = e.id.lowercasedString
    type = e.kind.rawValue
    occurredAt = e.occurredAt.millis
    tzOffset = e.tzOffsetMinutes
    appRef = e.appRef?.rawValue
    blockRef = e.blockRef?.rawValue
    appRefs = e.appRefs?.map(\.rawValue)
    via = e.via?.rawValue
    free = e.free
    waitMinutes = e.waitMinutes
    sessionMinutes = e.sessionMinutes
    schedule = e.schedule
    oldSchedule = e.oldSchedule
  }
}

struct EventBatch: Codable, Sendable {
  var deviceId: String
  var events: [EventWire]
}

struct EventBatchResult: Codable, Sendable {
  struct Rejected: Codable, Sendable {
    var id: String
    var reason: String
  }
  var accepted: [String]
  var rejected: [Rejected]
}
