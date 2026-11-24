import Foundation

/// The one optional card in Tonight's top status area (#102). A warning (Screen Time off, location)
/// holds the slot first; an offer shows only when nothing is wrong, so there is never more than one.
/// New kinds join `HomeSnapshot.card` in the order they should win.
public enum TonightCard: String, Codable, Hashable, Sendable, CaseIterable {
  /// "Only when I'm home?": from the morning after the first night, while home isn't set (D68).
  case home
  /// "A heads-up before your night?": from the morning after the first night, until iOS has been
  /// asked (D68, #104). Home goes first: one offer at a time.
  case headsUp
  /// Monday's card (D76): this week's gap, and last week's to keep. From the judgement at noon until
  /// Tuesday's noon, unless answered. It goes before the offers: it's about tonight.
  case gapWeek
  /// "Lock apps 15 min before bed?": once, for an install from before D76.
  case gapOffer
  /// "Something for the next 15 minutes?": once, in the gap before bed, introducing the "Before
  /// bed" capsule (D80). After warnings, home and the heads-up.
  case beforeBed
}

extension DuskState {
  /// Whether the Sleep block waits for home, as the user last chose it: a held edit counts (B-3), so
  /// the offer goes as soon as it's answered.
  public var homeIsSet: Bool {
    guard let sleep = sleepBlock else { return false }
    if case .save(let draft) = pending[sleep.id] { return draft.place != nil }
    return sleep.place != nil
  }

  public func dismissed(_ card: TonightCard) -> Bool {
    dismissedCards.contains(card.rawValue)
  }
}

extension HomeSnapshot {
  /// Offers are quiet: none while anything is blocked, none once the free week is over, none while a
  /// warning holds the slot. The one card that belongs to a locked evening is Before bed's, in the
  /// gap (D80); it comes after the others, which can't show while the lock is on.
  static func card(
    _ state: DuskState, now: Date, calendar: Calendar, warning: Bool,
    notifications: NotificationPermission, untilBed: Int? = nil
  ) -> TonightCard? {
    guard !warning, state.trial.entitled else { return nil }
    if state.isBlocking {
      return untilBed != nil && !state.dismissed(.beforeBed) ? .beforeBed : nil
    }
    guard let finished = state.setupFinishedAt, let sleep = state.sleepBlock else { return nil }
    // A night has ended since setup: the user has had one, and the offer has a reason.
    let nightEnded = sleep.schedule.lastEnd(atOrBefore: now, calendar: calendar).map {
      $0 > finished
    }
    guard nightEnded == true else { return nil }
    if let change = state.gap.change, !change.seen, change.week == nightKey(now, calendar) {
      return .gapWeek
    }
    if !state.homeIsSet, !state.dismissed(.home) { return .home }
    if notifications == .notAsked, !state.dismissed(.headsUp) { return .headsUp }
    if state.gap.offered, state.gap.minutes == 0 { return .gapOffer }
    return nil
  }
}
