import Foundation

/// A random device-local id for one picked token (spec §4). Events carry it; tokens never leave the device.
public struct AppRef: RawRepresentable, Codable, Hashable, Sendable, Comparable,
  ExpressibleByStringLiteral
{
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public init(stringLiteral value: String) { rawValue = value }
  public init(from decoder: Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(String.self)
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
  public static func < (lhs: AppRef, rhs: AppRef) -> Bool { lhs.rawValue < rhs.rawValue }
  public static func make() -> AppRef { AppRef(rawValue: UUID().uuidString.lowercased()) }
}

/// A block's id, shared with the server so schedule changes can be pinned for friends.
public struct BlockRef: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public init(stringLiteral value: String) { rawValue = value }
  public init(from decoder: Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(String.self)
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
  public static func make() -> BlockRef { BlockRef(rawValue: UUID().uuidString.lowercased()) }
}

/// The friends-facing name for an app ref (spec §4). Fixed list: no typos, no moderation.
public enum Tag: String, Codable, CaseIterable, Sendable {
  case instagram, tiktok, youtube, snapchat, x, reddit, other
}

/// What kind of picker token an app ref stands for.
public enum TokenKind: String, Codable, Sendable {
  case application, webDomain, category
}
