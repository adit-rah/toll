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

  public struct Trial: Codable, Sendable, Equatable {
    public init() {}
    public var nights = 7
  }

  public var window = Window()
  public var home = Home()
  public var door = Door()
  public var unlocks = Unlocks()
  public var trial = Trial()

  public init() {}

  public static let defaults = TollConfig()
}
