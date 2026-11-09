import Foundation

/// How the outbox sends events (E2.15): deduplicated by id, oldest first, in batches the server accepts,
/// with capped exponential backoff after failures.
public enum OutboxPlan {
  public static let batchLimit = 100
  public static let baseBackoff: TimeInterval = 5
  public static let maxBackoff: TimeInterval = 3600

  public static func batches(_ events: [GateEvent], limit: Int = batchLimit) -> [[GateEvent]] {
    var seen = Set<UUID>()
    let unique = events.sorted {
      ($0.occurredAt, $0.id.uuidString) < ($1.occurredAt, $1.id.uuidString)
    }
    .filter { seen.insert($0.id).inserted }
    return stride(from: 0, to: unique.count, by: max(1, limit)).map {
      Array(unique[$0..<min($0 + limit, unique.count)])
    }
  }

  /// Delay before retry number `failures` (1-based); jitter keeps many phones from retrying in step.
  public static func backoff(afterFailures failures: Int, jitter: Double = 0) -> TimeInterval {
    guard failures > 0 else { return 0 }
    let exponential = baseBackoff * pow(2, Double(min(failures - 1, 20)))
    return min(maxBackoff, exponential) * (1 + max(0, min(jitter, 0.25)))
  }

  /// Ids the server has settled: accepted ones, and ones it rejected for good (too old to ever accept).
  public static func settled(accepted: [String], rejected: [(id: String, reason: String)]) -> Set<
    String
  > {
    Set(accepted).union(rejected.map(\.id))
  }
}
