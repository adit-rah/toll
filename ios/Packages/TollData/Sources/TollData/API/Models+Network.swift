import Foundation
import TollCore

public struct HandleAvailability: Codable, Sendable, Equatable {
  public var available: Bool
  public var reason: String?
  public var suggestions: [String]
}

public struct MePatch: Codable, Sendable {
  public var displayName: String?
  public var handle: String?
  public var discoverable: Bool?
  public var timezone: String?
  public var notifyEnabled: Bool?
  public var notifyHour: Int?

  public init(
    displayName: String? = nil, handle: String? = nil, discoverable: Bool? = nil, timezone: String? = nil,
    notifyEnabled: Bool? = nil, notifyHour: Int? = nil
  ) {
    self.displayName = displayName
    self.handle = handle
    self.discoverable = discoverable
    self.timezone = timezone
    self.notifyEnabled = notifyEnabled
    self.notifyHour = notifyHour
  }
}

public struct PeopleResponse: Codable, Sendable, Equatable {
  public struct Request: Codable, Sendable, Equatable, Identifiable {
    public var user: PersonRef
    public var mutualNames: [String]
    public var id: String { user.id }
  }

  public struct Mutual: Codable, Sendable, Equatable, Identifiable {
    public var user: PersonRef
    public var via: [String]
    public var viaCount: Int
    public var level: Int?
    public var trend: Double?
    public var id: String { user.id }
  }

  public struct School: Codable, Sendable, Equatable {
    public var id: Int
    public var name: String
    public var members: Int
    public var heldPercent: Int?
  }

  public var requests: [Request]
  public var outgoing: [PersonRef]
  public var friends: [FriendSummary]
  public var mutuals: [Mutual]
  public var school: School?
}

public struct FriendRequestResult: Codable, Sendable {
  public var status: String
  public var user: PersonRef
}

public struct Invite: Codable, Sendable, Equatable {
  public var code: String
  public var url: String
}

public struct InvitePreview: Codable, Sendable, Equatable {
  public var displayName: String
}

public struct SchoolStatus: Codable, Sendable, Equatable {
  public var school: SchoolRef
  public var activeMembers: Int
  public var enough: Bool
  public var heldPercent: Int?
  public var medianPasses: Double?
  public var week: String
  public var asOf: Millis?
}

public struct SchoolMember: Codable, Sendable, Equatable, Identifiable {
  public var user: PersonRef
  public var relation: String
  public var level: Int?
  public var id: String { user.id }
}

public struct Bin: Codable, Sendable, Equatable, Hashable {
  public var from: Int
  public var to: Int
  public var count: Int
  public var includesMe: Bool
}

public struct FriendsInsights: Codable, Sendable, Equatable {
  public struct Person: Codable, Sendable, Equatable {
    public var user: PersonRef?
    public var isMe: Bool
    public var passes: Int
    public var hits: Int
    public var held: Int
    public var heldPercent: Int?
  }

  public struct Weekly: Codable, Sendable, Equatable {
    public var week: String
    public var heldPercent: Int?
    public var passesPerPerson: Double?
  }

  public struct Distribution: Codable, Sendable, Equatable {
    public var bins: [Bin]
  }

  public struct SameApp: Codable, Sendable, Equatable {
    public var tag: Tag
    public var count: Int
  }

  public var week: String
  public var people: [Person]
  public var distribution: Distribution?
  public var friendsByHour: [Int]
  public var myByHour: [Int]
  public var weekly: [Weekly]
  public var sameAppSameHour: SameApp?
  public var friendsHeldPercent: Int?
}

public struct SchoolInsights: Codable, Sendable, Equatable {
  public struct Weekly: Codable, Sendable, Equatable {
    public var week: String
    public var schoolHeldPercent: Int?
    public var myHeldPercent: Int?
  }

  public var enough: Bool
  public var school: SchoolRef?
  public var week: String
  public var asOf: Millis?
  public var distribution: FriendsInsights.Distribution?
  public var myBin: Int?
  public var schoolHeldPercent: Int?
  public var myHeldPercent: Int?
  public var weekly: [Weekly]
  public var byHour: [Double]
  public var myByHour: [Int]
  public var tagShare: [String: Double]
  public var examWeeks: [String]
}

public enum ReportReason: String, Codable, Sendable, CaseIterable {
  case name, photo, harassment, other
}

public enum Reauth: Sendable {
  case apple(authorizationCode: String, identityToken: String, nonce: String)
  case email(code: String)
}
