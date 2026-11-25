import Foundation

/// Everything the app and its extensions share, in one coordinated file in the App Group
/// (docs/architecture.md). Schema 1 was step 2's single-block state; `Migration` reads it.
public struct DuskState: Codable, Hashable, Sendable {
  public static let schema = 2

  public var schema = DuskState.schema
  public var blocks: [Block] = []
  public var places: [Place] = []
  public var presence: [PlaceID: Presence] = [:]
  public var location = LocationMode.places
  /// Edits to a block that was active when they were made; applied when it ends (B-3).
  public var pending: [BlockID: PendingEdit] = [:]
  /// Moves of a place an active block uses; applied when no active block uses it (B-3).
  public var pendingPlaces: [PlaceID: Place] = [:]
  public var door: Door?
  /// When a pause was last asked for, on the block screen or Tonight; the app opens the pause sheet if
  /// it is recent.
  public var doorAskedAt: Date?
  public var unlocks = UnlockSupply()
  public var trial = TrialState()
  public var setupFinishedAt: Date?
  /// Screen Time access for Dusk as the app last read it; nil until it has. Extensions can't read it,
  /// so they log what the app saw, and a night with it off is recorded as such (#60).
  public var screenTimeAllowed: Bool?
  /// Tonight cards the user dismissed (#102), by raw value: a kind a later build adds must not stop
  /// this file loading.
  public var dismissedCards: Set<String> = []
  /// The night whose card was put away (its noon-to-noon key): it floats again the next morning,
  /// and the strip opens it meanwhile.
  public var lastNightSeen: Date?
  /// The heads-up before each night, as the user last set it in Settings (D68); iOS's permission
  /// decides separately whether it can arrive.
  public var headsUp = true
  /// The gap before bed (D76). A file from before it keeps its night as it was (`Gap.existing`).
  public var gap = Gap()
  /// Before bed's helpers in the gap (D80): on unless switched off, and the breath's length.
  public var helpers = Helpers()
  public var runtime = RuntimeState()

  public init() {}

  public enum PendingEdit: Codable, Hashable, Sendable {
    case save(Block)
    case delete
  }

  public var sleepBlock: Block? { blocks.first(where: \.isSleep) }
  /// The night's block as it runs: locking the gap before bed (D76). Its stored hours are bed to
  /// wake; every rule about when it's on reads these.
  public var lockSleep: Block? { sleepBlock.map(locking) }
  /// Every block as it runs: the night's locks the gap before bed.
  public var lockBlocks: [Block] { blocks.map(locking) }

  public func locking(_ block: Block) -> Block {
    guard block.isSleep, gap.minutes > 0 else { return block }
    var lock = block
    lock.schedule = block.schedule.locking(gap.minutes)
    return lock
  }
  public func block(_ id: BlockID) -> Block? { blocks.first { $0.id == id } }
  public func place(_ id: PlaceID?) -> Place? { id.flatMap { id in places.first { $0.id == id } } }

  public var isBlocking: Bool { !runtime.active.isEmpty }
  public var activeBlocks: [Block] { blocks.filter { runtime.active[$0.id] != nil } }
}

/// Trial and purchase (P-2 to P-4). `entitled` is worked out by every reconcile so the trial ends on
/// time with the app closed (D23).
public struct TrialState: Codable, Hashable, Sendable {
  /// From the Keychain, so a reinstall does not start a new trial.
  public var start: Date?
  /// Mirrors the App Store's answer, so extensions can read it.
  public var purchased = false
  public var entitled = true

  public init() {}
}

/// What reconcile keeps between runs.
public struct RuntimeState: Codable, Hashable, Sendable {
  /// Active blocks and the end of the occurrence each is on for. The block screen reads it.
  public var active: [BlockID: Date] = [:]
  /// Each block's latest occurrence end seen; a block only starts for an occurrence that began after
  /// it (B-4).
  public var lastEnd: [BlockID: Date] = [:]
  /// Wall clock minus monotonic clock, renewed whenever a reconcile starts with nothing active (D12).
  public var clockAnchor: ClockAnchor?
  /// The windows the DeviceActivity schedules were last set to, so they are only replaced on a change.
  public var scheduledWindows: [TimeWindow]?
  /// The wait end of the pause whose schedule was started, so it is started once and stopped once.
  public var scheduledDoor: Date?

  public init() {}
}

/// Ties the wall clock to the monotonic clock within one boot.
public struct ClockAnchor: Codable, Hashable, Sendable {
  public var bootID: String
  public var offset: TimeInterval

  public init(bootID: String, offset: TimeInterval) {
    self.bootID = bootID
    self.offset = offset
  }

  init(wall: Date, monotonic: MonotonicInstant) {
    self.init(
      bootID: monotonic.bootID, offset: wall.timeIntervalSinceReferenceDate - monotonic.seconds)
  }

  func now(_ monotonic: MonotonicInstant?) -> Date? {
    guard let monotonic, monotonic.bootID == bootID else { return nil }
    return Date(timeIntervalSinceReferenceDate: offset + monotonic.seconds)
  }
}
