import Foundation

/// The buffers around sleep in the engine (D76, #144): each Monday at noon, with the pauses' week
/// (D70), last week is judged for each side; a change while the night's block is on waits until it
/// ends (B-3), so it applies from the next night. The week's facts are kept as they happen, so the
/// judgement needs no log.
enum GapRules {
  /// Run by every reconcile before the blocks are decided: judges every week that has ended since
  /// the last one, oldest first, on both sides.
  static func advance(_ state: inout DuskState, now: Date, calendar: Calendar, config: TollConfig) {
    for side in Gap.Side.allCases {
      advance(side, &state, now: now, calendar: calendar, config: config)
    }
  }

  static func advance(
    _ side: Gap.Side, _ state: inout DuskState, now: Date, calendar: Calendar, config: TollConfig
  ) {
    guard state.setupFinishedAt != nil else { return }
    let week = UnlockSupply.week(containing: now, calendar: calendar, config: config)
    guard let tallied = state[side].tally.week else {
      state[side].tally = Gap.Tally(week: week)
      return
    }
    // A clock set back to an earlier week judges nothing again.
    guard week > tallied else { return }
    var gap = state[side]
    // Judged from what the next night would use, a held change included.
    let before = gap.upcoming
    gap.minutes = before
    // A fixed buffer chosen tonight is fixed already: the rule leaves it alone.
    if case .fixed = gap.pending { gap.mode = .fixed }
    var tally = gap.tally
    var monday = tallied
    let step = config.limits(side).step
    // Weeks nothing reconciled through ran no nights: each one holds. Bounded, for a long absence.
    for _ in 0..<8 {
      guard let next = calendar.date(byAdding: .day, value: 7, to: monday), next <= week else {
        break
      }
      gap.minutes = gap.judge(tally, week: next, calendar: calendar, config: config, step: step)
      monday = next
      tally = Gap.Tally(week: next)
    }
    let after = gap.minutes
    gap.minutes = state[side].minutes
    gap.mode = state[side].mode
    gap.tally = Gap.Tally(week: week)
    state[side] = gap
    guard after != before, state[side].mode == .grows else { return }
    state[side].change = Gap.Change(week: week, from: before, to: after)
    set(side, .grows(after), &state, now: now, calendar: calendar, config: config)
  }

  /// The person's choice for the buffer before sleep, from Settings or a card.
  static func set(
    _ setting: Gap.Setting, _ state: inout DuskState, now: Date, calendar: Calendar,
    config: TollConfig
  ) {
    set(.before, setting, &state, now: now, calendar: calendar, config: config)
  }

  /// The person's choice for one side, and its target if they chose one. The minutes are held
  /// while the night's block is on (B-3); the target applies at once, since tonight's hours don't
  /// depend on it. A growing buffer never starts above its target.
  static func set(
    _ side: Gap.Side, _ setting: Gap.Setting, target: Int? = nil, _ state: inout DuskState,
    now: Date, calendar: Calendar, config: TollConfig
  ) {
    let limits = config.limits(side)
    if let target { state[side].target = Gap.clamped(target: target, limits: limits) }
    let setting = Gap.clamped(setting, target: state[side].target, limits: limits)
    state[side].offered = false
    if let sleep = state.sleepBlock, state.runtime.active[sleep.id] != nil {
      // What's already in force waits for nothing: Save with nothing changed, or choosing the
      // current one again, holds no change, so Settings never says one is waiting (#141).
      state[side].pending = setting == state[side].setting ? nil : setting
    } else {
      state[side].put(setting, now: now, calendar: calendar)
    }
  }

  /// Monday's card's "Keep 15": last week's buffer, still growing. The card names the side that
  /// changed, the buffer before sleep first; answering it answers both.
  static func keep(_ state: inout DuskState, now: Date, calendar: Calendar, config: TollConfig) {
    let sides = changes(state)
    seen(&state)
    for side in sides {
      guard let change = state[side].change, change.grew else { continue }
      set(side, .grows(change.from), &state, now: now, calendar: calendar, config: config)
    }
  }

  /// The side Monday's card leads with: an unseen change, before sleep first.
  static func changed(_ state: DuskState) -> Gap.Side? { changes(state).first }

  /// Every side whose change Monday's card is about: unseen, from the same Monday. When both
  /// changed, the card names both, so neither goes unsaid.
  static func changes(_ state: DuskState) -> [Gap.Side] {
    let unseen = Gap.Side.allCases.filter { state[$0].change.map { !$0.seen } ?? false }
    guard let week = unseen.first.flatMap({ state[$0].change?.week }) else { return [] }
    return unseen.filter { state[$0].change?.week == week }
  }

  static func seen(_ state: inout DuskState) {
    for side in Gap.Side.allCases { state[side].change?.seen = true }
  }

  /// B-3: a change held through the night applies once the night's block is off.
  static func applyHeld(
    _ state: inout DuskState, active: [BlockID: Date], now: Date, calendar: Calendar
  ) -> Bool {
    if let sleep = state.sleepBlock, active[sleep.id] != nil { return false }
    var changed = false
    for side in Gap.Side.allCases {
      guard let pending = state[side].pending else { continue }
      state[side].put(pending, now: now, calendar: calendar)
      changed = true
    }
    return changed
  }

  /// After the blocks are decided: the night's lock ran tonight, and whether Screen Time is off.
  static func tally(_ state: inout DuskState, now: Date, calendar: Calendar) {
    guard state.setupFinishedAt != nil else { return }
    for side in Gap.Side.allCases {
      if let sleep = state.sleepBlock, state.runtime.active[sleep.id] != nil {
        state[side].tally.nights.insert(nightKey(now, calendar))
      }
      if state.screenTimeAllowed == false { state[side].tally.screenTimeOff = true }
    }
  }

  /// A pause opened (D67): it counts against the buffer it was asked for in (D76, #144). A pause
  /// while asleep never counts against anyone.
  static func pauseOpened(_ state: inout DuskState, askedAt: Date, calendar: Calendar) {
    guard let night = sleep(state, at: askedAt, calendar: calendar) else { return }
    if askedAt < night.start {
      state.gap.tally.pausesInGap += 1
    } else if askedAt >= night.end {
      state.after.tally.pausesInGap += 1
    }
  }

  /// Bed for the night whose lock holds `date`; nil outside the lock's hours.
  static func bed(_ state: DuskState, at date: Date, calendar: Calendar) -> Date? {
    sleep(state, at: date, calendar: calendar)?.start
  }

  /// Sleep, bed to wake, for the night whose lock holds `date`; nil outside the lock's hours.
  static func sleep(_ state: DuskState, at date: Date, calendar: Calendar) -> TimeWindow.Night? {
    guard let lock = state.lockSleep?.schedule.occurrence(containing: date, calendar: calendar)
    else { return nil }
    return TimeWindow.Night(
      start: lock.start.addingTimeInterval(TimeInterval(state.gap.minutes * 60)),
      end: lock.end.addingTimeInterval(-TimeInterval(state.after.minutes * 60)))
  }
}
