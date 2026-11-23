import Foundation

/// Every tunable (MVP spec §10). Starting values, expected to change; nothing else holds a number.
public struct TollConfig: Codable, Sendable, Equatable {
  public struct Window: Codable, Sendable, Equatable {
    public init() {}
    /// Window start is wake time minus this many hours.
    public var leadHours = 8.5
  }

  public struct Home: Codable, Sendable, Equatable {
    public init() {}
    public var radiusMeters = 150.0
  }

  public struct Door: Codable, Sendable, Equatable {
    public init() {}
    /// The wait before a pause (D67); cancelling it costs nothing.
    public var waitSeconds = 60
    /// How long every shield lifts for (D67).
    public var minutes = 10
    public var regretSeconds = 120
  }

  public struct Unlocks: Codable, Sendable, Equatable {
    public init() {}
    /// Pauses a week, one pool for every block (D67).
    public var max = 3
    /// The weekday whose night starts a new week of pauses (`Calendar` numbering, 1 = Sunday): 2 is
    /// Monday (D67). Unused pauses don't carry over.
    public var refillWeekday = 2
  }

  public struct Blocks: Codable, Sendable, Equatable {
    public init() {}
    /// The canvas draws seven on Blocks · 8 time windows; windows are the limit that bites (D45).
    public var max = 8
    /// Across every block (D29); iOS refuses a shield of more than 50 by name.
    public var maxApps = 40
    /// Distinct time windows across every block: each needs a window and a sweep schedule, and
    /// DeviceActivity monitors at most 20 (docs/architecture.md).
    public var maxWindows = 8
  }

  public struct Trial: Codable, Sendable, Equatable {
    public init() {}
    public var nights = 7
  }

  public struct HeadsUp: Codable, Sendable, Equatable {
    public init() {}
    /// The one notification comes this long before each night (D68).
    public var leadMinutes = 20
    /// Nights scheduled at once, so each still gets its heads-up while the app stays closed.
    public var nightsAhead = 7
  }

  public var window = Window()
  public var home = Home()
  public var door = Door()
  public var unlocks = Unlocks()
  public var trial = Trial()
  public var blocks = Blocks()
  public var headsUp = HeadsUp()

  public init() {}

  public static let defaults = TollConfig()
}
