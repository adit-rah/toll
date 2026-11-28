import Foundation

extension Flows {
  /// #2, personal timing (D65, D107, #171): offered once, after the first week, to a person who
  /// chose Apple Health, since the model learns only from Health's sleep. Off until they say yes;
  /// put off for good, it stays off, and Settings › Sleep keeps the switch.
  public static let timing = OneTimeFlow(
    id: "personal-timing", version: 1,
    applies: { $0.setupFinishedAt != nil && $0.health && !$0.timing.on },
    ready: { state, now, calendar, config in
      nightsEnded(state, now: now, calendar: calendar) >= config.timing.offerAfterNights
    },
    defaults: { _ in [] })

  /// The night's hours that have ended since setup, however each went: a week lived with their
  /// own time before they're asked to let it move.
  static func nightsEnded(_ state: DuskState, now: Date, calendar: Calendar) -> Int {
    guard let setup = state.setupFinishedAt, let schedule = state.sleepBlock?.schedule else {
      return 0
    }
    return schedule.ends(after: setup, through: now, calendar: calendar).count
  }
}
