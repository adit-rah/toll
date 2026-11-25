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
  /// The night's block is on: a change now applies from tomorrow night (B-3).
  public var nightOn: Bool

  public init(state: DuskState, config: TollConfig = .defaults) {
    held = state.gap.pending != nil
    nightOn = state.sleepBlock.map { state.runtime.active[$0.id] != nil } ?? false
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

  /// The sheet's answer: a fixed gap as chosen, or growing from where it is now. A gap that starts
  /// growing begins at least at a new install's.
  public func choice(grows: Bool, fixed minutes: Int, config: TollConfig = .defaults)
    -> Gap.Setting
  {
    guard grows else { return .fixed(minutes) }
    if case .grows(let now) = setting { return .grows(now) }
    return Gap.clamped(.grows(max(minutes, config.gap.start)), config)
  }

  /// The minutes the sheet's fixed gap opens on.
  public var minutes: Int {
    switch setting {
    case .grows(let minutes), .fixed(let minutes): minutes
    }
  }

  public var grows: Bool { if case .grows = setting { true } else { false } }
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
      guard let side = GapRules.changed(state), let change = state[side].change else { return nil }
      title = side == .before ? Copy.Gap.weekCard(change.to) : Copy.Gap.afterWeekCard(change.to)
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
    case .home, .headsUp, .beforeBed:
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
