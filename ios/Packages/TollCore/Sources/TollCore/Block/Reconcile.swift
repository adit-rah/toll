import Foundation

/// The block rule and what follows from it (B-1 to B-6). Pure: the clock, the calendar and the state
/// in; the new state and the log line out. Every process that wakes runs it, so whichever runs next
/// corrects a callback that was missed.
public enum Reconcile {
  public struct Outcome: Hashable, Sendable {
    public var transition: Transition?
    public var settingsChanged: Bool
  }

  /// Launch and foreground run often and change nothing most times; only a change is worth a line.
  /// Every other cause is a wake the device protocol needs to see, changed or not.
  static let quietCauses: Set<ReconcileCause> = [.launch, .foreground]

  @discardableResult
  public static func run(
    _ state: inout SleepState, wall: Date, monotonic: MonotonicInstant?, calendar: Calendar,
    cause: ReconcileCause, config: TollConfig = .defaults
  ) -> Outcome {
    let before = state
    let now = trustedNow(&state, wall: wall, monotonic: monotonic)
    noteNightEnd(&state, now: now, calendar: calendar)
    var night = blockNight(state, now: now, calendar: calendar)
    if night == nil, let edit = state.pending {
      state.apply(edit)
      noteNightEnd(&state, now: now, calendar: calendar)
      night = blockNight(state, now: now, calendar: calendar)
    }
    state.blockOn = night != nil
    state.blockEndsAt = night?.end
    DoorRules.advance(&state, now: now, config: config)
    DoorRules.countNights(&state, now: now, calendar: calendar, config: config)
    let changed = state.blockOn != before.blockOn || state.door?.phase != before.door?.phase
    let inWindow = state.settings.window?.contains(now, calendar: calendar) ?? false
    let line =
      changed || !quietCauses.contains(cause)
      ? Transition(
        at: wall, cause: cause, blockOn: state.blockOn, changed: changed,
        home: state.presence?.isHome, inWindow: inWindow, entitled: state.entitled,
        door: state.door?.phase)
      : nil
    return Outcome(transition: line, settingsChanged: state.settings != before.settings)
  }

  /// During a block, the anchored time: setting the clock forward cannot end the night, and setting it
  /// back cannot hold it past the real morning. Outside a block the wall clock is taken as it is and
  /// the anchor renewed, so a corrected clock costs at most one night. After a restart there is no
  /// anchor and the wall clock decides.
  static func trustedNow(_ state: inout SleepState, wall: Date, monotonic: MonotonicInstant?)
    -> Date
  {
    if state.blockOn, let anchored = state.clockAnchor?.now(monotonic) { return anchored }
    state.clockAnchor = monotonic.map { ClockAnchor(wall: wall, monotonic: $0) }
    return wall
  }

  /// B-1: home (or location not in use, D8), inside the window, and entitled. B-4: and the night began after the last night end
  /// seen, so a clock set back or a flight west after the morning cannot bring the block back.
  static func blockNight(_ state: SleepState, now: Date, calendar: Calendar)
    -> SleepWindow.Night?
  {
    guard state.entitled, state.countsAsHome,
      let night = state.settings.window?.night(containing: now, calendar: calendar)
    else { return nil }
    if let last = state.lastNightEnd, night.start < last { return nil }
    return night
  }

  /// Only ever moves forward: a clock set back must not make an ended night look unfinished.
  static func noteNightEnd(_ state: inout SleepState, now: Date, calendar: Calendar) {
    guard let end = state.settings.window?.lastEnd(atOrBefore: now, calendar: calendar) else {
      return
    }
    state.lastNightEnd = max(state.lastNightEnd ?? end, end)
  }
}
