import Foundation

/// A card in Tonight's band (#102): an offer, or a card about the night. `TonightBand` decides
/// when each shows and which wins; a new kind adds its case here, its facts to `bandFacts`, and its
/// kind to `TonightCard.kind`.
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
  /// Each card's own facts, for `TonightBand`, which decides when each kind may show and which
  /// wins. Offers need a night to have ended since setup: the user has had one, and the offer has a
  /// reason.
  static func bandFacts(
    _ state: DuskState, now: Date, calendar: Calendar, notifications: NotificationPermission,
    untilBed: Int?
  ) -> TonightBand.Facts {
    var facts = TonightBand.Facts()
    facts.entitled = state.trial.entitled
    facts.blocking = state.isBlocking
    facts.nextLock = state.lockSleep?.schedule.nextStart(after: now, calendar: calendar)
    facts.beforeBed = untilBed != nil && !state.dismissed(.beforeBed)
    if let finished = state.setupFinishedAt, let sleep = state.sleepBlock {
      facts.nightEnded =
        sleep.schedule.lastEnd(atOrBefore: now, calendar: calendar).map { $0 > finished } == true
    }
    if let change = state.gap.change, !change.seen, change.week == nightKey(now, calendar) {
      facts.gapWeek = true
    }
    facts.setup = setupOffer(state, notifications: notifications)
    return facts
  }

  /// Home, then the heads-up, then the gap offer: one offer at a time (D72).
  static func setupOffer(_ state: DuskState, notifications: NotificationPermission) -> TonightCard?
  {
    if !state.homeIsSet, !state.dismissed(.home) { return .home }
    if notifications == .notAsked, !state.dismissed(.headsUp) { return .headsUp }
    if state.gap.offered, state.gap.minutes == 0 { return .gapOffer }
    return nil
  }
}
