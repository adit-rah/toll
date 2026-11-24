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
    /// A block's name fits one line on the block screen's title (#62).
    public var maxNameLength = 24
    /// The hours a new block starts with, by kind, so adding one is a kind, the apps and Save (#89).
    /// Study, Work and Other share 9 to 5 on weekdays: blocks with the same hours share one time
    /// window (D40), so the defaults don't use up the eight.
    public var study = Hours(start: ClockTime(hour: 9), end: ClockTime(hour: 17))
    public var work = Hours(start: ClockTime(hour: 9), end: ClockTime(hour: 17))
    public var gym = Hours(start: ClockTime(hour: 18), end: ClockTime(hour: 19))
    public var other = Hours(start: ClockTime(hour: 9), end: ClockTime(hour: 17))
  }

  /// One default rule: a window on some days.
  public struct Hours: Codable, Sendable, Equatable {
    public var start: ClockTime
    public var end: ClockTime
    public var days: Set<Weekday>

    public init(start: ClockTime, end: ClockTime, days: Set<Weekday> = Weekday.weekdays) {
      self.start = start
      self.end = end
      self.days = days
    }
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

  /// The lock starts a gap before bed, and the gap grows with smooth weeks (D76). The weekly rule's
  /// numbers are `datascience/sim/gap_rule.py`'s, so the app does what the simulator measured.
  public struct Gap: Codable, Sendable, Equatable {
    public init() {}
    /// A new install's gap; installs from before D76 keep 0 and are offered this once.
    public var start = 15
    public var step = 15
    /// The weekly rule never grows it past this; a person may choose more by hand.
    public var cap = 60
    public var manualMax = 90
    /// Settings' fixed gap moves in these steps, 0 to `manualMax`.
    public var manualStep = 15
    /// A smooth week: the lock ran at least this many nights, at most `smoothMaxPauses` pauses
    /// started inside the gap, and Screen Time was never off.
    public var smoothMinNights = 4
    public var smoothMaxPauses = 1
    /// A hard week: at least this many pauses started inside the gap.
    public var hardPauses = 2
    /// After Screen Time is switched off, the next this many Mondays don't grow it.
    public var offFreezeWeeks = 2
    /// After an ease, smooth weeks in a row before it grows again.
    public var smoothAfterEase = 2
  }

  public struct Sky: Codable, Sendable, Equatable {
    public init() {}
    /// Nights the lock ran that make a quiet landmark morning, the only times the sky can be
    /// shared (D79).
    public var landmarks = [7, 30, 100, 365]
  }

  public var window = Window()
  public var home = Home()
  public var door = Door()
  public var unlocks = Unlocks()
  public var trial = Trial()
  public var blocks = Blocks()
  public var headsUp = HeadsUp()
  public var gap = Gap()
  public var sky = Sky()

  public init() {}

  public static let defaults = TollConfig()
}
