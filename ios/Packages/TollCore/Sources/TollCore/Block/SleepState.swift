import Foundation

/// Where home is: the one point the user confirmed, and the radius around it (spec §3, §9).
public struct HomePoint: Codable, Hashable, Sendable {
  public var latitude: Double
  public var longitude: Double
  public var radiusMeters: Double

  public init(latitude: Double, longitude: Double, radiusMeters: Double) {
    self.latitude = latitude
    self.longitude = longitude
    self.radiusMeters = radiusMeters
  }
}

/// What the user chose. Edited as a whole, so an edit made during a block waits as one (B-3).
public struct SleepSettings: Codable, Hashable, Sendable {
  public var window: SleepWindow?
  public var home: HomePoint?
  /// The encoded `FamilyActivitySelection`. Opaque here: only the Screen Time glue can read it.
  public var keepOpen: Data?

  public init(window: SleepWindow? = nil, home: HomePoint? = nil, keepOpen: Data? = nil) {
    self.window = window
    self.home = home
    self.keepOpen = keepOpen
  }
}

/// The last word from region monitoring: one boolean and when it came (spec §9).
public struct Presence: Codable, Hashable, Sendable {
  public var isHome: Bool
  public var at: Date

  public init(isHome: Bool, at: Date) {
    self.isHome = isHome
    self.at = at
  }
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

  /// The wall time the anchor implies now, or nil after a restart.
  func now(_ monotonic: MonotonicInstant?) -> Date? {
    guard let monotonic, monotonic.bootID == bootID else { return nil }
    return Date(timeIntervalSinceReferenceDate: offset + monotonic.seconds)
  }
}

/// How "home" is known (decisions D8). Without Always and Precise location the region cannot run with
/// the app closed, and the paid block must not depend on location: the window alone decides.
public enum HomeCheck: String, Codable, Hashable, Sendable {
  case location
  case windowOnly
}

/// Everything the app and the extensions share in the App Group (spec §6).
public struct SleepState: Codable, Hashable, Sendable {
  /// True when the block treats the user as home: the region says so, or location is not in use.
  public var countsAsHome: Bool { homeCheck == .windowOnly || presence?.isHome == true }

  public var settings = SleepSettings()
  /// An edit made while the block was on; applied when it next turns off (B-3).
  public var pending: SleepSettings?
  /// Nil until the home region reports, and again after home moves.
  public var presence: Presence?
  public var homeCheck = HomeCheck.location
  /// Nil until the last setup screen is passed; the app opens on setup until then.
  public var setupFinishedAt: Date?
  /// Trial or purchase (P-2, P-3). True until the trial is built (§12 step 7).
  public var entitled = true
  public var blockOn = false
  /// The end of the night the block is on for. The block screen reads it.
  public var blockEndsAt: Date?
  /// The latest night end seen. A block only starts for a night that begins after it (B-4).
  public var lastNightEnd: Date?
  /// Wall clock minus monotonic clock, taken whenever a reconcile starts with the block off. While
  /// the block is on, time is read through it, so changing the clock does not move the night (B-4).
  public var clockAnchor: ClockAnchor?
  /// The window the DeviceActivity schedule was last set to, so it is only replaced on a change.
  public var scheduledWindow: SleepWindow?

  public init() {}

  /// An edit from the user: held while the block is on, applied at once otherwise (B-3).
  public mutating func submit(_ edit: SleepSettings) {
    if blockOn {
      pending = edit
    } else {
      apply(edit)
    }
  }

  mutating func apply(_ edit: SleepSettings) {
    if edit.home != settings.home { presence = nil }
    settings = edit
    pending = nil
  }
}
