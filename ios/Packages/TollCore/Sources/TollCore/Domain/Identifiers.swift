import Foundation

/// Ids are strings in the state file so it reads plainly; the types keep a block id from being passed
/// where a place id is meant.
public struct BlockID: Codable, Hashable, Sendable, Comparable {
  public var raw: String
  public init(_ raw: String) { self.raw = raw }
  public static func make() -> BlockID { BlockID(UUID().uuidString.lowercased()) }
  public init(from decoder: Decoder) throws {
    raw = try decoder.singleValueContainer().decode(String.self)
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(raw)
  }
  public static func < (lhs: BlockID, rhs: BlockID) -> Bool { lhs.raw < rhs.raw }
}

public struct PlaceID: Codable, Hashable, Sendable, Comparable {
  public var raw: String
  public init(_ raw: String) { self.raw = raw }
  public static func make() -> PlaceID { PlaceID(UUID().uuidString.lowercased()) }
  public init(from decoder: Decoder) throws {
    raw = try decoder.singleValueContainer().decode(String.self)
  }
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(raw)
  }
  public static func < (lhs: PlaceID, rhs: PlaceID) -> Bool { lhs.raw < rhs.raw }
}

/// ISO numbering (Monday = 1), so a week reads in the order people say it.
public enum Weekday: Int, Codable, CaseIterable, Comparable, Sendable {
  case monday = 1
  case tuesday, wednesday, thursday, friday, saturday, sunday

  public static let all = Set(allCases)
  public static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
  /// Nights before a workday: Sunday to Thursday.
  public static let schoolNights: Set<Weekday> = [
    .sunday, .monday, .tuesday, .wednesday, .thursday,
  ]
  public static let weekendNights: Set<Weekday> = [.friday, .saturday]

  public init(of date: Date, calendar: Calendar) {
    let gregorian = calendar.component(.weekday, from: date)
    self = Weekday(rawValue: (gregorian + 5) % 7 + 1) ?? .monday
  }

  public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Lets the ids key JSON objects (`{"<id>": …}`) instead of the array of pairs `Codable` writes for
/// other key types, so the state file stays readable.
struct IDKey: CodingKey {
  var stringValue: String
  var intValue: Int? { nil }
  init(stringValue: String) { self.stringValue = stringValue }
  init?(intValue: Int) { nil }
}

extension BlockID: CodingKeyRepresentable {
  public var codingKey: any CodingKey { IDKey(stringValue: raw) }
  public init?<T: CodingKey>(codingKey: T) { self.init(codingKey.stringValue) }
}

extension PlaceID: CodingKeyRepresentable {
  public var codingKey: any CodingKey { IDKey(stringValue: raw) }
  public init?<T: CodingKey>(codingKey: T) { self.init(codingKey.stringValue) }
}
