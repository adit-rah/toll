import Foundation

/// Settings › Before bed (D76): the gap as the person last chose it, a change held through tonight
/// included (B-3).
public struct BeforeBed: Equatable, Sendable {
  /// What the sheet opens on.
  public var setting: Gap.Setting
  /// "Grows with you · now 30 min · next 45", or "Fixed · 30 min".
  public var detail: String
  /// A change waits for tonight's night to end.
  public var held: Bool

  public init(state: DuskState, config: TollConfig = .defaults) {
    held = state.gap.pending != nil
    setting = state.gap.pending ?? state.gap.setting
    switch setting {
    case .grows(let minutes):
      var gap = state.gap
      gap.minutes = minutes
      gap.mode = .grows
      detail = Copy.Gap.growsDetail(minutes, next: gap.next(config))
    case .fixed(let minutes):
      detail = Copy.Gap.fixedDetail(minutes)
    }
    if held { detail += Copy.middleDot + Copy.Gap.fromTomorrow }
  }

  /// The fixed gaps Settings offers, 0 to the manual most.
  public static func choices(_ config: TollConfig = .defaults) -> [Int] {
    Array(stride(from: 0, through: config.gap.manualMax, by: max(1, config.gap.manualStep)))
  }
}

/// The words on Tonight's gap cards (D76): Monday's, and the one offer to an install from before it.
public struct GapCard: Equatable, Sendable {
  public var title: String
  public var detail: String?
  /// "Keep 15", "Turn on"; nil when the card only informs (an ease, D65).
  public var action: String?
  public var dismiss: String

  init?(_ card: TonightCard, state: DuskState, now: Date, calendar: Calendar, config: TollConfig) {
    switch card {
    case .gapWeek:
      guard let change = state.gap.change else { return nil }
      title = Copy.Gap.weekCard(change.to)
      detail = change.grew ? Copy.Gap.upFrom(change.from) : nil
      action = change.grew ? Copy.Gap.keep(change.from) : nil
      dismiss = Copy.Gap.okay
    case .gapOffer:
      guard
        let schedule = state.sleepBlock?.schedule.locking(config.gap.start),
        let start = schedule.nextStart(after: now, calendar: calendar),
        let night = schedule.occurrence(containing: start, calendar: calendar)
      else { return nil }
      title = Copy.Gap.offerCard(config.gap.start)
      detail = Copy.Gap.offerDetail(
        lock: Copy.time(start, in: calendar), wake: Copy.time(night.end, in: calendar))
      action = Copy.Gap.turnOn
      dismiss = Copy.Home.notNow
    case .home, .headsUp:
      return nil
    }
  }
}

extension HomeSnapshot {
  static func gapCard(
    _ card: TonightCard?, state: DuskState, now: Date, calendar: Calendar, config: TollConfig
  ) -> GapCard? {
    card.flatMap { GapCard($0, state: state, now: now, calendar: calendar, config: config) }
  }
}
