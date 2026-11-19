import Foundation

/// The door (D-1 to D-7, D31), across every block: one at a time, unlocks shared.
public enum DoorRules {
  public enum Refusal: Error, Equatable, Sendable {
    case notBlocked, alreadyOpen, noneLeft
  }

  /// D-1, D-5, D-7: only while a block is on, one at a time, while unlocks are left.
  static func start(_ state: inout DuskState, app: Data, now: Date, config: TollConfig) -> Refusal?
  {
    guard state.isBlocking else { return .notBlocked }
    guard state.door == nil else { return .alreadyOpen }
    guard state.unlocks.left(config) > 0 else { return .noneLeft }
    state.door = Door(
      app: app, waitEndsAt: now.addingTimeInterval(TimeInterval(config.door.waitSeconds)))
    return nil
  }

  /// D-3: cancelling during the wait costs nothing.
  static func cancel(_ state: inout DuskState) {
    if state.door?.phase == .waiting { state.door = nil }
  }

  /// D-4: within the regret time, the unlock comes back and the night is clean again.
  static func lockAgain(_ state: inout DuskState, now: Date, config: TollConfig) {
    guard let door = state.door else { return }
    if door.phase == .open, let regretEnd = door.regretEndsAt(config), now <= regretEnd {
      state.unlocks.spent = max(0, state.unlocks.spent - 1)
      state.unlocks.used = max(0, state.unlocks.used - 1)
      state.unlocks.lastSpendAt = door.spendBefore
    }
    state.door = nil
  }

  /// Run by every reconcile after the blocks are decided. Opens a door whose wait is over (D-3), closes
  /// one whose minutes are up (D31), and ends any door when no block is on.
  static func advance(_ state: inout DuskState, now: Date, config: TollConfig) {
    guard var door = state.door else { return }
    guard state.isBlocking else {
      state.door = nil
      return
    }
    if door.phase == .waiting, now >= door.waitEndsAt {
      door.openedAt = now
      // From the planned end of the wait, so the expiry is the moment the DeviceActivity warning fires.
      door.expiresAt = door.waitEndsAt.addingTimeInterval(TimeInterval(config.door.minutes * 60))
      door.spendBefore = state.unlocks.lastSpendAt
      state.unlocks.spent += 1
      state.unlocks.used += 1
      state.unlocks.lastSpendAt = now
    }
    state.door = (door.expiresAt.map { now >= $0 } ?? false) ? nil : door
  }

  /// The door's DeviceActivity interval: the platform's minimum, with its warning at the door's minutes
  /// (D31). Its end backs the warning up.
  public static func intervalMinutes(_ config: TollConfig) -> Int {
    max(config.door.minutes, TimeWindow.minimumMinutes)
  }

  /// D-6: each Sleep night end since the last count is one night; a spend since the previous one
  /// resets the run. Seven clean nights in a row return one unlock, up to the maximum.
  static func countNights(
    _ state: inout DuskState, now: Date, calendar: Calendar, config: TollConfig
  ) {
    guard let sleep = state.sleepBlock?.schedule else { return }
    guard let from = state.unlocks.countedThrough else {
      state.unlocks.countedThrough = sleep.lastEnd(atOrBefore: now, calendar: calendar)
      return
    }
    var previous = from
    for end in sleep.ends(after: from, through: now, calendar: calendar) {
      if let spend = state.unlocks.lastSpendAt, spend > previous, spend <= end {
        state.unlocks.cleanNights = 0
      } else {
        state.unlocks.cleanNights += 1
      }
      if state.unlocks.cleanNights >= config.unlocks.refillNights {
        state.unlocks.cleanNights = 0
        state.unlocks.spent = max(0, state.unlocks.spent - 1)
      }
      state.unlocks.countedThrough = end
      previous = end
    }
  }
}
