import Foundation

/// The shared state file (D11): one coordinated JSON file in the App Group, read and written by the
/// app and the extensions. It never loses a person (#140): older files are migrated on read, values
/// it can't read fall back or drop alone, a file it can't read at all is kept aside rather than
/// written over, and a newer build's file it mustn't write (`minReader`) is only read.
public struct DuskStore: StatePort {
  public let url: URL
  /// Where the night comes back from when the file has lost it (`Recovery`).
  let nights: NightLog
  /// Written into the file as `writtenBy`.
  let build: String?

  public init(url: URL = AppGroup.file("state.json"), nights: NightLog = NightLog()) {
    self.url = url
    self.nights = nights
    let info = Bundle.main.infoDictionary
    build = (info?["CFBundleShortVersionString"] as? String).map { version in
      (info?["CFBundleVersion"] as? String).map { "\(version) (\($0))" } ?? version
    }
  }

  /// Never writes: ShieldConfig reads through this alone.
  public func load() -> DuskState {
    loadIfReadable() ?? DuskState()
  }

  /// Nil when the file is there but can't be opened, so a reader keeps what it had.
  public func loadIfReadable() -> DuskState? {
    switch CoordinatedFile.contents(url) {
    case .missing: DuskState()
    case .unreadable: nil
    case .data(let data): read(data, now: Date()).state
    }
  }

  public func update<T>(_ body: (inout DuskState, StateAccess) -> T) -> Stored<T>? {
    var stored: Stored<T>?
    CoordinatedFile.change(url) { contents, writer in
      let now = Date()
      var state: DuskState
      var access = StateAccess.saved
      switch contents {
      case .unreadable:
        return
      case .missing:
        state = DuskState()
      case .data(let data):
        let reading = read(data, now: now)
        state = reading.state
        if !reading.writable {
          access = .readOnly
        } else if let keep = reading.keep(now: now), !writer.has(keep) {
          // Nothing is written until the file as it was is safe beside it.
          if writer.keep(data, as: keep) {
            Kept.prune(beside: writer.url)
          } else {
            access = .readOnly
          }
        }
      }
      let value = body(&state, access)
      if access == .saved {
        state.schema = DuskState.schema
        state.minReader = state.reader
        state.writtenBy = build
        if (try? Self.encoder.encode(state)).map(writer.replace(with:)) != true {
          access = .readOnly
        }
      }
      stored = Stored(value: value, access: access)
    }
    return stored
  }

  /// The file as this build reads it, and whether it may write it back.
  struct Reading {
    var state: DuskState
    /// The schema the file was written at; nil when it couldn't be read at all.
    var schema: Int?
    var writable = true
    /// Values given up while reading it.
    var lost = 0

    /// The copy to keep before the first write over this file, if one is needed.
    func keep(now: Date) -> String? {
      guard let schema else { return "state.unreadable-\(Kept.stamp(now))" }
      if lost > 0 { return "state.partial-\(Kept.stamp(now))" }
      if schema != DuskState.schema { return "state.v\(schema)" }
      return nil
    }
  }

  func read(_ data: Data, now: Date) -> Reading {
    var reading = Self.reading(data)
    // Lost: the file couldn't be read, or it was set up and its night couldn't be.
    let lost = reading.schema == nil || reading.state.setupFinishedAt != nil
    if lost, reading.state.sleepBlock == nil {
      Recovery.restoreNight(&reading.state, from: nights.latestRecord(), now: now)
    }
    return reading
  }

  /// The state a file holds, migrated: what every reader works from.
  static func decode(_ data: Data) -> DuskState { reading(data).state }

  /// Migrates, then decodes lossily; nothing here writes.
  static func reading(_ data: Data) -> Reading {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return Reading(state: DuskState(), schema: nil)
    }
    if object["schema"] == nil, object["settings"] != nil {
      guard let legacy = try? decoder.decode(LegacyStateV1.self, from: data) else {
        return Reading(state: DuskState(), schema: nil)
      }
      return Reading(state: Migration.fromV1(legacy), schema: 1)
    }
    let labelled = object["schema"] as? Int ?? 2
    // Every build that writes `minReader` writes it. Without it, the file was written by a build
    // from before #140, which kept whatever `schema` it read: a newer number over its own shape,
    // after a downgrade. So it's that build's shape, schema 2, whatever the label says.
    let schema = object["minReader"] == nil ? min(labelled, 2) : labelled
    let minReader = object["minReader"] as? Int ?? schema
    var source = data
    if schema < DuskState.schema {
      let upgraded = Migration.upgrade(object, from: schema)
      guard let json = try? JSONSerialization.data(withJSONObject: upgraded) else {
        return Reading(state: DuskState(), schema: nil)
      }
      source = json
    }
    guard
      let (state, lost) = try? DecodeReport.collect({
        try decoder.decode(DuskState.self, from: source)
      })
    else { return Reading(state: DuskState(), schema: nil) }
    var current = state
    current.schema = DuskState.schema
    current.minReader = current.reader
    return Reading(
      state: current, schema: schema, writable: minReader <= DuskState.schema, lost: lost)
  }

  static var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = .sortedKeys
    return encoder
  }

  static var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}

/// The copies kept beside the state file: the newest few of each kind, so they never pile up.
enum Kept {
  static let kinds = ["state.unreadable-", "state.partial-"]
  static let keep = 3

  static func stamp(_ date: Date) -> String { String(Int(date.timeIntervalSince1970)) }

  static func prune(beside url: URL) {
    let folder = url.deletingLastPathComponent()
    let manager = FileManager.default
    guard let names = try? manager.contentsOfDirectory(atPath: folder.path) else { return }
    for kind in kinds {
      let mine = names.filter { $0.hasPrefix(kind) }.sorted { stampOf($0) > stampOf($1) }
      for name in mine.dropFirst(keep) {
        try? manager.removeItem(at: folder.appending(path: name))
      }
    }
  }

  private static func stampOf(_ name: String) -> Int {
    Int(name.drop { !$0.isNumber }.prefix { $0.isNumber }) ?? 0
  }
}

extension TransitionLog: LogPort {}
