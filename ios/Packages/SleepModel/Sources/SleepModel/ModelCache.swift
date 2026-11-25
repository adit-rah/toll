import Foundation

/// One person's model as the app keeps it, `model.json` in the App Group (#140). It's a cache: the
/// night log is the truth, and the state can always be rebuilt from it (D52). A new artifact
/// rebuilds it from every night; otherwise it moves on by the nights after the last it saw, and a
/// night it saw that has changed since (a correction, or a night written late) rebuilds it too.
public struct ModelCache: Codable, Sendable, Equatable {
  public static let schema = 1

  /// Which artifact built the state. The version names it; the checksum tells two builds of one
  /// version apart.
  public struct Artifact: Codable, Sendable, Equatable {
    public var version: String
    public var sha256: String
  }

  /// What the state has seen: the nights up to `through`, how many, and the sum of their revisions,
  /// so a correction or a late night before `through` shows as a change.
  public struct Seen: Codable, Sendable, Equatable {
    public var through: String?
    public var nights: Int
    public var revisions: Int

    static func of(_ records: [NightRecord], through: String?) -> Seen {
      let held = records.filter { record in through.map { record.night <= $0 } ?? false }
      return Seen(
        through: through, nights: held.count, revisions: held.map(\.revision).reduce(0, +))
    }
  }

  public var schema = ModelCache.schema
  public var artifact: Artifact
  /// The policy the records are stamped with (`ModelStamp` in TollCore reads it).
  public var policy: String
  public var seen: Seen
  public var state: PersonState

  /// The cache brought up to `records` (one per night, in night order: `current`), and whether
  /// it had to be rebuilt from the start.
  public static func refreshed(
    _ cache: ModelCache?, artifact: ModelArtifact, policy: String, records: [NightRecord]
  ) -> (cache: ModelCache, rebuilt: Bool) {
    let id = Artifact(version: artifact.version, sha256: artifact.sha256 ?? "")
    if let cache, cache.schema == schema, cache.artifact == id, cache.policy == policy,
      Seen.of(records, through: cache.seen.through) == cache.seen
    {
      var model = SleepModel(artifact: artifact, state: cache.state)
      let new = records.filter { night in cache.seen.through.map { night.night > $0 } ?? true }
      for night in new { model.update(with: night) }
      let through = records.last?.night ?? cache.seen.through
      return (
        ModelCache(
          artifact: id, policy: policy, seen: .of(records, through: through), state: model.state),
        false
      )
    }
    let model = SleepModel(artifact: artifact, nights: records)
    return (
      ModelCache(
        artifact: id, policy: policy, seen: .of(records, through: records.last?.night),
        state: model.state),
      true
    )
  }

  /// One record per night from the night log's lines: its highest revision, the first written of
  /// equals, in night order. The same rule as TollCore's `NightLog` and `dusk_model.night.latest`.
  /// A line that isn't a record is left out.
  public static func current(_ lines: [Data]) -> [NightRecord] {
    let decoder = JSONDecoder()
    var best: [String: NightRecord] = [:]
    for line in lines {
      guard let record = try? decoder.decode(NightRecord.self, from: line) else { continue }
      if let held = best[record.night], held.revision >= record.revision { continue }
      best[record.night] = record
    }
    return best.keys.sorted().compactMap { best[$0] }
  }
}

extension NightRecord {
  public var revision: Int { rev ?? 1 }
}
