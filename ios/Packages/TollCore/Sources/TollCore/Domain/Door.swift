import Foundation

/// One pause (D67; spec §3's door, D-3 and D-4 kept): a wait, then every block's shield lifts for a
/// few minutes on the clock (D31). The code keeps the spec's name; the user sees "Pause".
public struct Door: Codable, Hashable, Sendable {
  public enum Phase: String, Codable, Hashable, Sendable {
    case waiting, open
  }

  public var waitEndsAt: Date
  public var openedAt: Date?
  /// The end of its minutes (D31): the wait's end plus the door's minutes, the moment the door's
  /// DeviceActivity warning fires.
  public var expiresAt: Date?

  public var phase: Phase { openedAt == nil ? .waiting : .open }

  public init(waitEndsAt: Date) {
    self.waitEndsAt = waitEndsAt
  }

  /// Within the regret time of opening, "Lock again" returns the pause (D-4).
  public func regretEndsAt(_ config: TollConfig) -> Date? {
    openedAt?.addingTimeInterval(TimeInterval(config.door.regretSeconds))
  }
}

/// The week's pauses (D67): a few a week, one pool for every block, back to the full count at the
/// start of the refill weekday's night. Stored as the number spent in a keyed week, so a change to
/// `unlocks.max` needs no migration and a week that has passed reads as nothing spent.
public struct UnlockSupply: Codable, Hashable, Sendable {
  /// Spent in `week`.
  public var spent = 0
  /// The night key (the day it starts, noon to noon) of the refill night that began `spent`'s week.
  public var week: Date?
  /// Every pause ever kept (returned ones excluded), for the trial-ended summary (D24).
  public var used = 0

  public init() {}

  /// Spent in the week that holds `now`: nothing once that week is over, so none carry over. A clock
  /// set back to an earlier week refills nothing.
  public func spent(now: Date, calendar: Calendar, config: TollConfig) -> Int {
    guard let week else { return 0 }
    return Self.week(containing: now, calendar: calendar, config: config) > week ? 0 : spent
  }

  public func left(_ config: TollConfig, now: Date, calendar: Calendar) -> Int {
    max(0, config.unlocks.max - spent(now: now, calendar: calendar, config: config))
  }

  /// The night key: the day twelve hours earlier, so 1 am belongs with the evening before.
  public static func night(of date: Date, calendar: Calendar) -> Date {
    calendar.startOfDay(for: date.addingTimeInterval(-12 * 3600))
  }

  /// The refill night that began the week holding `now`. Keyed by night, so a Sunday night doesn't
  /// refill at midnight: Monday's night starts at noon.
  public static func week(containing now: Date, calendar: Calendar, config: TollConfig) -> Date {
    let night = night(of: now, calendar: calendar)
    let back = (calendar.component(.weekday, from: night) - config.unlocks.refillWeekday + 7) % 7
    return calendar.date(byAdding: .day, value: -back, to: night) ?? night
  }

  /// When the next week of pauses starts: noon on the next refill day.
  public static func refill(after now: Date, calendar: Calendar, config: TollConfig) -> Date {
    let week = week(containing: now, calendar: calendar, config: config)
    let next = calendar.date(byAdding: .day, value: 7, to: week) ?? week
    return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: next) ?? next
  }
}
