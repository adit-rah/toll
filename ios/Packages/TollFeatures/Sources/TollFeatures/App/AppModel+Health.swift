import Foundation
import TollCore
import TollData

/// Apple Health's sleep (#144): the rules are TollCore's (`SleepNight`, `SleepEstimate`,
/// `BufferSuggestion`); the adapter is TollData's `SleepSource`. Read only, and only after the
/// person chose "Use Apple Health".
extension AppModel {
  /// "Use Apple Health": iOS's sheet, then the recent nights. Nil when there aren't enough, or
  /// reading was refused, which iOS doesn't tell apart.
  func readSleep() async -> SleepEstimate? {
    let source = SleepSource()
    guard source.available else { return nil }
    await source.requestRead()
    let nights = await source.nights(now: now, calendar: .current, config: config)
    return SleepEstimate(nights, now: now, calendar: .current, config: config)
  }

  /// "See how you slept" (#86), for someone who skipped Health at setup: iOS's sheet, then
  /// Health's sleep for the nights recorded. Health counts as chosen whatever iOS answers, since a
  /// refusal reads as no nights; Your sleep then says a watch adds real sleep times.
  func askHealth() async {
    let source = SleepSource()
    guard source.available else { return }
    await source.requestRead()
    send(.foreground, [.health(true)])
    await correctNightsFromHealth()
  }

  /// The day after a night, its record gets Health's sleep as a correction (D92's `rev`). Only for
  /// people who chose Health, and only for the last `health.correctDays`.
  func correctNightsFromHealth() async {
    guard state.health else { return }
    let since = Calendar.current.date(
      byAdding: .day, value: -config.health.correctDays, to: Date())
    guard let since, !NightLog().missingSleep(since: since, calendar: .current).isEmpty else {
      return
    }
    let nights = await SleepSource().nights(now: Date(), calendar: .current, config: config)
    guard !nights.isEmpty else { return }
    _ = await Task.detached(priority: .utility) {
      NightLog().correct(with: nights, calendar: .current)
    }.value
    history = NightLog().past(calendar: .current)
  }
}
