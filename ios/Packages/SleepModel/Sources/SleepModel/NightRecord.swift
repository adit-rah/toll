import Foundation

/// One night as the app logs it (model spec, contract 1). Times are local ISO 8601 with the offset,
/// kept as written; the model reads them through `LocalTime`. Since the lock starts a gap before bed
/// (decisions D76), `plannedBedtime` is bed and the record says the gap; a record from before has
/// neither, and its gap was 0. Since the helpers before bed (D80) it can name the one used; that is
/// private to the pilot, and the model never reads it.
public struct NightRecord: Codable, Sendable, Equatable {
  public var night: String
  public var plannedBedtime: String
  public var plannedWake: String
  /// Bed, the same as `plannedBedtime` since D76; nil in older records.
  public var bed: String?
  /// Minutes the lock was planned to start before bed; nil in older records, which had none.
  public var gapMin: Int?
  public var blockStart: String?
  public var blockEnd: String?
  public var actionOffsetMin: Int
  public var actionProb: Double
  public var modelVersion: String
  public var policy: String
  public var homeArrival: String?
  public var awayAllNight: Bool
  public var weekend: Bool
  public var tzChanged: Bool
  public var blockScreens: Int?
  public var unlocksUsed: Int?
  public var unlocksReturned: Int?
  public var sleepOnset: String?
  public var wake: String?
  public var asleepMin: Int?
  public var awakeMin: Int?
  public var sleepSource: String?
  /// The helper last opened before bed that night ("list", "breathe", "words"); nil when none was,
  /// and in older records.
  public var helper: String?

  enum CodingKeys: String, CodingKey {
    case night, policy, weekend, wake, bed, helper
    case gapMin = "gap_min"
    case plannedBedtime = "planned_bedtime"
    case plannedWake = "planned_wake"
    case blockStart = "block_start"
    case blockEnd = "block_end"
    case actionOffsetMin = "action_offset_min"
    case actionProb = "action_prob"
    case modelVersion = "model_version"
    case homeArrival = "home_arrival"
    case awayAllNight = "away_all_night"
    case tzChanged = "tz_changed"
    case blockScreens = "block_screens"
    case unlocksUsed = "unlocks_used"
    case unlocksReturned = "unlocks_returned"
    case sleepOnset = "sleep_onset"
    case asleepMin = "asleep_min"
    case awakeMin = "awake_min"
    case sleepSource = "sleep_source"
  }
}

/// What is known about a night before it starts, and the starts the person allows.
public struct NightContext: Sendable, Equatable {
  public var weekend: Bool
  public var late: Bool
  /// Starts the person allows, in minutes from plan; nil allows every action in the artifact.
  public var allowedOffsets: [Int]?

  public init(weekend: Bool = false, late: Bool = false, allowedOffsets: [Int]? = nil) {
    self.weekend = weekend
    self.late = late
    self.allowedOffsets = allowedOffsets
  }
}

/// Why a night teaches the model nothing. Checked in this order, as in `dusk_model/night.py`.
public enum SkipReason: String, Sendable, Equatable {
  case noSleepData = "no_sleep_data"
  case away
  case tzChanged = "tz_changed"
  case noBlock = "no_block"
  case unknownAction = "unknown_action"
  case onsetFar = "onset_far"
}

public struct NightFeatures: Sendable, Equatable {
  public var skip: SkipReason?
  /// Sleep onset in minutes from planned bedtime; 0 when skipped.
  public var onset: Double
  public var offset: Int
  public var context: NightContext
}

extension NightRecord {
  /// Bed: sleep onset is measured from it, never from the lock.
  public var bedtime: String { bed ?? plannedBedtime }
  public var gap: Int { gapMin ?? 0 }

  public func context(_ artifact: ModelArtifact) -> NightContext {
    var late = false
    if let bedtime = LocalTime(bedtime), let arrival = homeArrival.flatMap(LocalTime.init) {
      late = bedtime.minutes(since: arrival) < artifact.context.lateHomeWithinMin
    }
    return NightContext(weekend: weekend, late: late)
  }

  public func features(_ artifact: ModelArtifact) -> NightFeatures {
    let context = context(artifact)
    func skip(_ reason: SkipReason) -> NightFeatures {
      NightFeatures(skip: reason, onset: 0, offset: actionOffsetMin, context: context)
    }
    guard let onset = sleepOnset.flatMap(LocalTime.init) else { return skip(.noSleepData) }
    if awayAllNight { return skip(.away) }
    if tzChanged { return skip(.tzChanged) }
    guard blockStart != nil else { return skip(.noBlock) }
    guard artifact.actions.contains(actionOffsetMin) else { return skip(.unknownAction) }
    guard let bedtime = LocalTime(bedtime) else { return skip(.noSleepData) }
    let y = onset.minutes(since: bedtime)
    guard abs(y) <= artifact.usableNight.maxOnsetFromPlanMin else { return skip(.onsetFar) }
    return NightFeatures(skip: nil, onset: y, offset: actionOffsetMin, context: context)
  }
}
