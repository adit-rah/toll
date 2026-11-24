import Foundation

/// The gap before bed in the engine (D76): each Monday at noon, with the pauses' week (D70), last
/// week is judged; a change while the night's block is on waits until it ends (B-3), so it applies
/// from the next night. The week's facts are kept as they happen, so the judgement needs no log.
enum GapRules {
  /// Run by every reconcile before the blocks are decided: judges every week that has ended since
  /// the last one, oldest first.
  static func advance(_ state: inout DuskState, now: Date, calendar: Calendar, config: TollConfig) {
    guard state.setupFinishedAt != nil else { return }
    let week = UnlockSupply.week(containing: now, calendar: calendar, config: config)
    guard let tallied = state.gap.tally.week else {
      state.gap.tally = Gap.Tally(week: week)
      return
    }
    // A clock set back to an earlier week judges nothing again.
    guard week > tallied else { return }
    var gap = state.gap
    // Judged from what the next night would use, a held change included.
    let before = gap.upcoming
    gap.minutes = before
    var tally = gap.tally
    var monday = tallied
    // Weeks nothing reconciled through ran no nights: each one holds. Bounded, for a long absence.
    for _ in 0..<8 {
      guard let next = calendar.date(byAdding: .day, value: 7, to: monday), next <= week else {
        break
      }
      gap.minutes = gap.judge(tally, week: next, calendar: calendar, config: config)
      monday = next
      tally = Gap.Tally(week: next)
    }
    let after = gap.minutes
    gap.minutes = state.gap.minutes
    gap.tally = Gap.Tally(week: week)
    state.gap = gap
    guard after != before, state.gap.mode == .grows else { return }
    state.gap.change = Gap.Change(week: week, from: before, to: after)
    set(.grows(after), &state, now: now, calendar: calendar, config: config)
  }

  /// The person's choice, from Settings or a card. Held while the night's block is on (B-3).
  static func set(
    _ setting: Gap.Setting, _ state: inout DuskState, now: Date, calendar: Calendar,
    config: TollConfig
  ) {
    let setting = Gap.clamped(setting, config)
    state.gap.offered = false
    if let sleep = state.sleepBlock, state.runtime.active[sleep.id] != nil {
      state.gap.pending = setting
    } else {
      state.gap.put(setting, now: now, calendar: calendar)
    }
  }

  /// Monday's card's "Keep 15": last week's gap, still growing.
  static func keep(_ state: inout DuskState, now: Date, calendar: Calendar, config: TollConfig) {
    guard var change = state.gap.change, !change.seen else { return }
    change.seen = true
    state.gap.change = change
    set(.grows(change.from), &state, now: now, calendar: calendar, config: config)
  }

  /// B-3: a change held through the night applies once the night's block is off.
  static func applyHeld(
    _ state: inout DuskState, active: [BlockID: Date], now: Date, calendar: Calendar
  ) -> Bool {
    guard let pending = state.gap.pending else { return false }
    if let sleep = state.sleepBlock, active[sleep.id] != nil { return false }
    state.gap.put(pending, now: now, calendar: calendar)
    return true
  }

  /// After the blocks are decided: the night's lock ran tonight, and whether Screen Time is off.
  static func tally(_ state: inout DuskState, now: Date, calendar: Calendar) {
    guard state.setupFinishedAt != nil else { return }
    if let sleep = state.sleepBlock, state.runtime.active[sleep.id] != nil {
      state.gap.tally.nights.insert(nightKey(now, calendar))
    }
    if state.screenTimeAllowed == false { state.gap.tally.screenTimeOff = true }
  }

  /// A pause opened (D67): it counts against the week when it was asked for before bed (D76). A
  /// pause after bed never counts against anyone.
  static func pauseOpened(_ state: inout DuskState, askedAt: Date, calendar: Calendar) {
    guard let bed = bed(state, at: askedAt, calendar: calendar), askedAt < bed else { return }
    state.gap.tally.pausesInGap += 1
  }

  /// Bed for the night whose lock holds `date`; nil outside the lock's hours.
  static func bed(_ state: DuskState, at date: Date, calendar: Calendar) -> Date? {
    guard let lock = state.lockSleep?.schedule.occurrence(containing: date, calendar: calendar)
    else { return nil }
    return lock.start.addingTimeInterval(TimeInterval(state.gap.minutes * 60))
  }
}
