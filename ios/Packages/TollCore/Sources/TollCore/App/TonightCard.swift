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
}

extension DuskState {
  /// Whether the Sleep block waits for home, as the user last chose it: a held edit counts (B-3), so
  /// the offer goes as soon as it's answered.
  public var homeIsSet: Bool {
    guard let sleep = sleepBlock else { return false }
    if case .save(let draft) = pending[sleep.id] { return draft.place != nil }
    return sleep.place != nil
  }

  /// When a change to "Only when I'm home" made during the night takes effect (B-3): the night's
  /// end, while the held edit changes the place. Nil when nothing waits.
  public var homeChangeAt: Date? {
    guard let sleep = sleepBlock, case .save(let draft) = pending[sleep.id],
      draft.place != sleep.place
    else { return nil }
    return runtime.active[sleep.id]
  }

  public func dismissed(_ card: TonightCard) -> Bool {
    dismissedCards.contains(card.rawValue)
  }
}

extension HomeSnapshot {
  /// Offers are quiet: none while anything is blocked, none once the free week is over, none while a
  /// warning holds the slot.
  static func card(
    _ state: DuskState, now: Date, calendar: Calendar, warning: Bool,
    notifications: NotificationPermission
  ) -> TonightCard? {
    guard !warning, !state.isBlocking, state.trial.entitled,
      let finished = state.setupFinishedAt, let sleep = state.sleepBlock
    else { return nil }
    // A night has ended since setup: the user has had one, and the offer has a reason.
    let nightEnded = sleep.schedule.lastEnd(atOrBefore: now, calendar: calendar).map {
      $0 > finished
    }
    guard nightEnded == true else { return nil }
    if !state.homeIsSet, !state.dismissed(.home) { return .home }
    if notifications == .notAsked, !state.dismissed(.headsUp) { return .headsUp }
    return nil
  }
}
