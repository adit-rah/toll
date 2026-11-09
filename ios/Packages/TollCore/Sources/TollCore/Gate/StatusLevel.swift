import Foundation

/// The three-level glyph (spec §4 Status, design §3.1). Level 1 is fewer passes.
public enum StatusLevel: Int, Codable, Sendable, CaseIterable {
  case fewer = 1
  case usual = 2
  case more = 3
}

public enum StatusRules {
  public static let personalisedHistoryDays = 28
  public static let minimumHistoryDays = 7

  /// Thresholds for the first week; after a full week of history, centred on the person's own median
  /// with a band of a quarter of it (at least one pass). The server uses the same rule
  /// (`fixtures/status-levels.json`).
  public static func level(passesToday: Int, history: [Int], config: TollConfig.Status)
    -> StatusLevel
  {
    if config.personalise, history.count >= minimumHistoryDays {
      let recent = Array(history.suffix(personalisedHistoryDays))
      let median = Self.median(recent)
      let band = max(1, (median * 0.25).rounded())
      if Double(passesToday) < median - band { return .fewer }
      if Double(passesToday) > median + band { return .more }
      return .usual
    }
    let bounds = config.levelBounds
    if passesToday <= (bounds.first ?? 2) { return .fewer }
    if passesToday <= (bounds.dropFirst().first ?? 4) { return .usual }
    return .more
  }

  static func median(_ values: [Int]) -> Double {
    let sorted = values.sorted()
    guard !sorted.isEmpty else { return 0 }
    let mid = sorted.count / 2
    return sorted.count.isMultiple(of: 2)
      ? Double(sorted[mid - 1] + sorted[mid]) / 2 : Double(sorted[mid])
  }
}
