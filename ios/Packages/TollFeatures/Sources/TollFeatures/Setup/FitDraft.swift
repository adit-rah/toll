import Foundation
import Observation
import TollCore

/// Dusk fitted to someone's sleep, while they choose (#144): onboarding's steps, the one-time flow
/// for people already using Dusk and Settings › Sleep all edit one of these and send its `fit`.
/// Nothing reaches the shared state until they do.
@MainActor
@Observable
final class FitDraft {
  let config: TollConfig
  var asleep: ClockTime
  var wake: ClockTime
  /// Fri and Sat nights have their own times ("Different on weekends").
  var weekendsDiffer = false
  var weekendAsleep: ClockTime
  var weekendWake: ClockTime
  var before: Fit.Buffer
  var after: Fit.Buffer
  /// "Use Apple Health" was chosen; the night log then gets Health's sleep.
  var health: Bool
  /// What Health said, when it had enough nights; the sleep step says it.
  private(set) var estimate: SleepEstimate?
  /// Waiting for iOS's sheet and Health's nights.
  var reading = false

  init(
    config: TollConfig, schedule: WeeklySchedule?, before: Fit.Buffer, after: Fit.Buffer,
    health: Bool
  ) {
    self.config = config
    let rules = schedule?.rules ?? []
    let week =
      rules.first { !$0.days.isDisjoint(with: Weekday.schoolNights) }?.window
      ?? TimeWindow(wake: ClockTime(hour: 7), leadHours: config.window.leadHours)
    let weekend = rules.first { $0.days == Weekday.weekendNights }?.window
    asleep = week.start
    wake = week.end
    weekendsDiffer = weekend != nil && rules.count == 2
    weekendAsleep = weekend?.start ?? week.start
    weekendWake = weekend?.end ?? week.end.adding(minutes: 120)
    self.before = before
    self.after = after
    self.health = health
  }

  /// A new person: 7 am, the night's usual length before it, and the recommended buffers.
  static func fresh(_ config: TollConfig) -> FitDraft {
    let fit = Fit.suggested(sleep: nil, health: false, config: config)
    return FitDraft(
      config: config, schedule: nil, before: fit.before, after: fit.after, health: false)
  }

  /// Someone already using Dusk: their night and gap as they are (`Fit.existing`).
  static func existing(_ state: DuskState, config: TollConfig) -> FitDraft {
    let fit = Fit.existing(state, config: config)
    return FitDraft(
      config: config, schedule: fit.sleep, before: fit.before, after: fit.after,
      health: fit.health)
  }

  /// Health answered: its usual times, weekends apart when they differ. Nil leaves the times to
  /// the person. The buffers stay the recommended baseline either way.
  func found(_ estimate: SleepEstimate?) {
    self.estimate = estimate
    guard let estimate else { return }
    asleep = estimate.usual.asleep
    wake = estimate.usual.wake
    weekendsDiffer = estimate.weekends != nil
    if let weekends = estimate.weekends {
      weekendAsleep = weekends.asleep
      weekendWake = weekends.wake
    }
  }

  var window: TimeWindow { TimeWindow(start: asleep, end: wake) }
  var weekendWindow: TimeWindow { TimeWindow(start: weekendAsleep, end: weekendWake) }

  var schedule: WeeklySchedule {
    guard weekendsDiffer else { return .everyDay(window) }
    return WeeklySchedule(rules: [
      .init(days: Weekday.schoolNights, window: window),
      .init(days: Weekday.weekendNights, window: weekendWindow),
    ])
  }

  /// The night's hours can be locked: each window long enough, and the lock under a day.
  var isValid: Bool {
    schedule.isValid
      && schedule.locking(before: before.start, after: after.start).isValid
  }

  var fit: Fit { Fit(sleep: schedule, before: before, after: after, health: health) }

  /// One side's start, inside 0 and its target.
  func setStart(_ side: Gap.Side, _ minutes: Int) {
    var buffer = side == .before ? before : after
    buffer.start = min(max(minutes, 0), buffer.target)
    if side == .before { before = buffer } else { after = buffer }
  }

  /// One side's target, at least its start and at most what a person may choose.
  func setTarget(_ side: Gap.Side, _ minutes: Int) {
    var buffer = side == .before ? before : after
    buffer.target = min(max(minutes, buffer.start), config.limits(side).manualMax)
    if side == .before { before = buffer } else { after = buffer }
  }

  /// What drives the sleep step's words: found in Health, or asked.
  var foundInHealth: Bool { estimate != nil }
}
