import Foundation

/// Settings › Sleep (D76, #144): one buffer as the person last chose it, a change held through
/// tonight included (B-3).
public struct BeforeBed: Equatable, Sendable {
  public var side: Gap.Side
  /// What the sheet opens on.
  public var setting: Gap.Setting
  /// What growing aims for.
  public var target: Int
  /// "Grows with you · now 30 min · next 45", or "Fixed · 30 min".
  public var detail: String
  /// A change waits for tonight's night to end.
  public var held: Bool
  /// The night's block is on: a change now applies from tomorrow night (B-3).
  public var nightOn: Bool

  public init(state: DuskState, side: Gap.Side = .before, config: TollConfig = .defaults) {
    self.side = side
    let gap = state[side]
    held = gap.pending != nil
    nightOn = state.sleepBlock.map { state.runtime.active[$0.id] != nil } ?? false
    setting = gap.pending ?? gap.setting
    target = gap.target
    switch setting {
    case .grows(let minutes):
      var gap = gap
      gap.minutes = minutes
      gap.mode = .grows
      detail = Copy.Gap.growsDetail(minutes, next: gap.next(config.limits(side).step))
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
    return Gap.clamped(
      .grows(max(minutes, config.limits(side).start)), target: target,
      limits: config.limits(side))
  }

  /// Settings › Sleep's row: "10:30 pm – 7:00 am · 15 min before · 10 min after", as chosen, a
  /// change held through tonight included (B-3). Weeknights' hours when weekends differ.
  public static func sleepRow(_ state: DuskState) -> String {
    var sleep = state.sleepBlock
    if let id = sleep?.id, case .save(let held) = state.pending[id] { sleep = held }
    let hours = sleep?.schedule.windows.first.map { Copy.span($0, short: true) } ?? ""
    return Copy.Fit.rowDetail(
      sleep: hours, before: state.gap.upcoming, after: state.after.upcoming)
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
      let changes = GapRules.changes(state).compactMap { side in
        state[side].change.map { (side, $0) }
      }
      guard let (side, change) = changes.first else { return nil }
      let grew = changes.filter { $0.1.grew }.map(\.1)
      if changes.count > 1, let after = changes.last?.1 {
        title = Copy.Gap.bothWeekCard(before: change.to, after: after.to)
      } else {
        title = side == .before ? Copy.Gap.weekCard(change.to) : Copy.Gap.afterWeekCard(change.to)
      }
      // An ease says only the new numbers (D65); a rise says what it was, and offers it back.
      switch grew.count {
      case 0: (detail, action) = (nil, nil)
      case 1: (detail, action) = (Copy.Gap.upFrom(grew[0].from), Copy.Gap.keep(grew[0].from))
      default:
        (detail, action) = (Copy.Gap.upFromBoth(grew[0].from, grew[1].from), Copy.Gap.keepBoth)
      }
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
