import Foundation
import Synchronization

/// Decoding that never loses the whole file for one bad value (#140): a missing key takes its
/// default, an unknown enum value its safe fallback, and an element that can't be read is dropped
/// with the rest kept. Everything given up is counted, so the store can keep the file as it was
/// before writing over it.
final class DecodeReport: Sendable {
  private let count = Mutex(0)

  /// The report the current decode adds to, if anyone is listening.
  @TaskLocal static var current: DecodeReport?

  var lost: Int { count.withLock { $0 } }

  static func note() {
    current?.count.withLock { $0 += 1 }
  }

  /// Runs `body` with a fresh report; returns what it gave up alongside its result.
  static func collect<T>(_ body: () throws -> T) rethrows -> (T, lost: Int) {
    let report = DecodeReport()
    let value = try $current.withValue(report, operation: body)
    return (value, report.lost)
  }
}

/// Ids and other string-keyed values, so a JSON object decodes key by key.
protocol StringKeyed: Hashable {
  init(_ raw: String)
}

extension BlockID: StringKeyed {}
extension PlaceID: StringKeyed {}
extension String: StringKeyed {
  init(_ raw: String) { self = raw }
}

extension Decoder {
  /// A raw-valued enum that reads an unknown value as `fallback` instead of failing: a value written
  /// by a newer build, or one this build removed.
  func raw<T: RawRepresentable>(or fallback: T) throws -> T where T.RawValue: Decodable {
    let raw = try singleValueContainer().decode(T.RawValue.self)
    guard let value = T(rawValue: raw) else {
      DecodeReport.note()
      return fallback
    }
    return value
  }
}

/// Skips one element of an array that couldn't be read.
private struct Skip: Decodable {
  init(from decoder: Decoder) throws {}
}

extension KeyedDecodingContainer {
  /// The value, or nil when it's missing or null; one that can't be read is nil too, and counted.
  func lossy<T: Decodable>(_ key: Key) -> T? {
    guard contains(key), (try? decodeNil(forKey: key)) == false else { return nil }
    do {
      return try decode(T.self, forKey: key)
    } catch {
      DecodeReport.note()
      return nil
    }
  }

  func lossy<T: Decodable>(_ key: Key, or fallback: T) -> T {
    lossy(key) ?? fallback
  }

  /// Every element that can be read, in order.
  func lossyArray<T: Decodable>(_ key: Key) -> [T] {
    guard contains(key), (try? decodeNil(forKey: key)) == false else { return [] }
    guard var items = try? nestedUnkeyedContainer(forKey: key) else {
      DecodeReport.note()
      return []
    }
    var result: [T] = []
    while !items.isAtEnd {
      if let item = try? items.decode(T.self) {
        result.append(item)
      } else {
        DecodeReport.note()
        guard (try? items.decode(Skip.self)) != nil else { break }
      }
    }
    return result
  }

  func lossySet<T: Decodable & Hashable>(_ key: Key) -> Set<T> {
    Set(lossyArray(key) as [T])
  }

  /// Every entry of a JSON object that can be read.
  func lossyMap<ID: StringKeyed, V: Decodable>(_ key: Key) -> [ID: V] {
    guard contains(key), (try? decodeNil(forKey: key)) == false else { return [:] }
    guard let entries = try? nestedContainer(keyedBy: IDKey.self, forKey: key) else {
      DecodeReport.note()
      return [:]
    }
    var result: [ID: V] = [:]
    for entry in entries.allKeys {
      if let value = try? entries.decode(V.self, forKey: entry) {
        result[ID(entry.stringValue)] = value
      } else {
        DecodeReport.note()
      }
    }
    return result
  }
}
