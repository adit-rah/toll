import Foundation

/// The pause (D67, with D-3, D-4, D-7 and D31 kept), across every block: one at a time, a weekly
/// supply shared by all blocks.
public enum DoorRules {
  public enum Refusal: Error, Equatable, Sendable {
    case notBlocked, alreadyOpen, noneLeft
  }

  /// Only while a block is on, one at a time, while pauses are left this week.
  static func start(_ state: inout DuskState, now: Date, calendar: Calendar, config: TollConfig)
    -> Refusal?
  {
    guard state.isBlocking else { return .notBlocked }
    guard state.door == nil else { return .alreadyOpen }
    guard state.unlocks.left(config, now: now, calendar: calendar) > 0 else { return .noneLeft }
    state.door = Door(waitEndsAt: now.addingTimeInterval(TimeInterval(config.door.waitSeconds)))
    return nil
  }

  /// D-3: cancelling during the wait costs nothing.
  static func cancel(_ state: inout DuskState) {
    if state.door?.phase == .waiting { state.door = nil }
  }

  /// D-4: within the regret time, the pause comes back.
  static func lockAgain(
    _ state: inout DuskState, now: Date, calendar: Calendar, config: TollConfig
  ) {
    guard let door = state.door else { return }
    if door.phase == .open, let regretEnd = door.regretEndsAt(config), now <= regretEnd {
      rollWeek(&state, now: now, calendar: calendar, config: config)
      state.unlocks.spent = max(0, state.unlocks.spent - 1)
      state.unlocks.used = max(0, state.unlocks.used - 1)
    }
    state.door = nil
  }

  /// Run by every reconcile after the blocks are decided. Opens a pause whose wait is over (D-3),
  /// closes one whose minutes are up (D31), and ends any pause when no block is on.
  static func advance(_ state: inout DuskState, now: Date, calendar: Calendar, config: TollConfig) {
    rollWeek(&state, now: now, calendar: calendar, config: config)
    guard var door = state.door else { return }
    guard state.isBlocking else {
      state.door = nil
      return
    }
    if door.phase == .waiting, now >= door.waitEndsAt {
      door.openedAt = now
      // From the planned end of the wait, so the expiry is the moment the DeviceActivity warning fires.
      door.expiresAt = door.waitEndsAt.addingTimeInterval(TimeInterval(config.door.minutes * 60))
      state.unlocks.spent += 1
      state.unlocks.used += 1
      GapRules.pauseOpened(
        &state, askedAt: door.waitEndsAt.addingTimeInterval(-TimeInterval(config.door.waitSeconds)),
        calendar: calendar)
    }
    state.door = (door.expiresAt.map { now >= $0 } ?? false) ? nil : door
  }

  /// A new week starts with nothing spent: unused pauses don't carry over (D67).
  static func rollWeek(_ state: inout DuskState, now: Date, calendar: Calendar, config: TollConfig)
  {
    let week = UnlockSupply.week(containing: now, calendar: calendar, config: config)
    guard state.unlocks.week.map({ week > $0 }) ?? true else { return }
    state.unlocks.spent = state.unlocks.spent(now: now, calendar: calendar, config: config)
    state.unlocks.week = week
  }

  /// The pause's DeviceActivity interval: the platform's minimum, with its warning at the pause's
  /// minutes (D31). Its end backs the warning up.
  public static func intervalMinutes(_ config: TollConfig) -> Int {
    max(config.door.minutes, TimeWindow.minimumMinutes)
  }
}
