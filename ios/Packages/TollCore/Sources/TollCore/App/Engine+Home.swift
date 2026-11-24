import Foundation

extension Engine {
  /// Onboarding doesn't ask where home is (D68): until it's set, the Sleep block has no place and runs
  /// on its hours wherever the phone is, the same path as without Always (D37). Setting it later saves
  /// Home and points the Sleep block at it, both as ordinary edits, so a night that's on keeps going as
  /// it started (B-3).
  static func setHome(
    _ place: Place, in state: inout DuskState, now: Date, calendar: Calendar, config: TollConfig
  ) -> CommandError? {
    guard var sleep = state.sleepBlock else { return .noSleepBlock }
    // A held edit is the user's latest word on the block; home is added to it, not to the old one.
    if case .save(let held) = state.pending[sleep.id] { sleep = held }
    if let error = apply(
      .savePlace(place), to: &state, now: now, calendar: calendar, config: config)
    {
      return error
    }
    sleep.place = place.id
    return apply(.saveBlock(sleep), to: &state, now: now, calendar: calendar, config: config)
  }

  /// The way back from "Only when I'm home" (the audit): the night runs on its hours again.
  static func useAnywhere(
    in state: inout DuskState, now: Date, calendar: Calendar, config: TollConfig
  ) -> CommandError? {
    guard var sleep = state.sleepBlock else { return .noSleepBlock }
    if case .save(let held) = state.pending[sleep.id] { sleep = held }
    sleep.place = nil
    return apply(.saveBlock(sleep), to: &state, now: now, calendar: calendar, config: config)
  }
}
