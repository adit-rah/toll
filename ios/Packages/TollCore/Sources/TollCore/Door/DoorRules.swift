import Foundation

/// What the user and the callbacks can do to the door (D-1 to D-7). Each returns whether it changed
/// anything; the caller reconciles after, in the same write.
public enum DoorRules {
  public enum Refusal: Error, Equatable, Sendable {
    case notBlocked, alreadyOpen, noneLeft
  }

  /// D-1, D-5, D-7: only during a block, one at a time, while unlocks are left.
  public static func start(
    _ state: inout SleepState, app: Data, now: Date, config: TollConfig
  ) -> Refusal? {
    guard state.blockOn else { return .notBlocked }
    guard state.door == nil else { return .alreadyOpen }
    guard state.unlocks.left(config) > 0 else { return .noneLeft }
    state.door = Door(
      app: app, waitEndsAt: now.addingTimeInterval(TimeInterval(config.door.waitSeconds)))
    return nil
  }

  /// D-3: cancelling during the wait costs nothing.
  public static func cancel(_ state: inout SleepState) {
    if state.door?.phase == .waiting { state.door = nil }
  }

  /// D-4: within the regret time, the unlock comes back and the night is clean again.
  public static func lockAgain(_ state: inout SleepState, now: Date, config: TollConfig) {
    guard let door = state.door else { return }
    if door.phase == .open, let regretEnd = door.regretEndsAt(config), now <= regretEnd {
      state.unlocks.spent = max(0, state.unlocks.spent - 1)
      state.unlocks.lastSpendAt = door.spendBefore
    }
    state.door = nil
  }

  public static func usedUp(_ state: inout SleepState) {
    if state.door?.phase == .open { state.door?.usedUp = true }
  }

  /// Run by every reconcile after the block is decided. Opens a door whose wait is over (D-2, D-3),
  /// closes one that is used up or past its stored expiry, and ends any door when the block ends.
  static func advance(_ state: inout SleepState, now: Date, config: TollConfig) {
    guard var door = state.door else { return }
    guard state.blockOn else {
      state.door = nil
      return
    }
    if door.phase == .waiting, now >= door.waitEndsAt {
      door.openedAt = now
      door.expiresAt = now.addingTimeInterval(intervalSeconds(config))
      door.spendBefore = state.unlocks.lastSpendAt
      state.unlocks.spent += 1
      state.unlocks.lastSpendAt = now
    }
    if door.usedUp || (door.expiresAt.map { now >= $0 } ?? false) {
      state.door = nil
    } else {
      state.door = door
    }
  }

  /// The door's DeviceActivity interval: the use time, but never under the platform's minimum. Its
  /// end is the stored expiry when the usage callback does not come (spec §5, decisions D20).
  public static func intervalSeconds(_ config: TollConfig) -> TimeInterval {
    TimeInterval(max(config.door.minutes, SleepWindow.minimumMinutes) * 60)
  }

  /// D-6: each night end since the last count is one night; a spend inside it resets the run. Seven
  /// clean nights in a row return one unlock, up to the maximum.
  static func countNights(
    _ state: inout SleepState, now: Date, calendar: Calendar, config: TollConfig
  ) {
    guard let window = state.settings.window else { return }
    guard let from = state.unlocks.countedThrough else {
      state.unlocks.countedThrough = window.lastEnd(atOrBefore: now, calendar: calendar)
      return
    }
    for end in window.ends(after: from, through: now, calendar: calendar) {
      if let spend = state.unlocks.lastSpendAt, spend > from, spend <= end {
        state.unlocks.cleanNights = 0
      } else {
        state.unlocks.cleanNights += 1
      }
      if state.unlocks.cleanNights >= config.unlocks.refillNights {
        state.unlocks.cleanNights = 0
        state.unlocks.spent = max(0, state.unlocks.spent - 1)
      }
      state.unlocks.countedThrough = end
    }
  }
}
