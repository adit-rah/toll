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
    public var waitSeconds = 90
    public var minutes = 5
    public var regretSeconds = 120
  }

  public struct Unlocks: Codable, Sendable, Equatable {
    public init() {}
    public var max = 3
    public var refillNights = 7
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

  public var window = Window()
  public var home = Home()
  public var door = Door()
  public var unlocks = Unlocks()
  public var trial = Trial()
  public var blocks = Blocks()

  public init() {}

  public static let defaults = TollConfig()
}
