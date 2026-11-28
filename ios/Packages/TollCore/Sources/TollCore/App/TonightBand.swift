import Foundation

/// Tonight's band (D86): what floats between the state and the strip. Each kind of item has its own
/// part of the day, so kinds rarely meet; where they do, one full card wins by kind, and last
/// night's folded row may sit under it, nearest the strip. Never more than two, and the state never
/// moves (`docs/flows/tonight.md`, "Tonight's band").
public struct TonightBand: Equatable, Sendable {
  /// What an item is for, which says when it may show. A card's priority is this order.
  public enum Kind: Int, CaseIterable, Comparable, Sendable {
    /// Something is wrong (Screen Time off, a build that can't save, a night without its apps,
    /// location short of Always). At any time, until it's fixed.
    case problem
    /// About the night itself: Before bed's card in the gap, Monday's card before the lock. They
    /// lose their reason once the night has passed, so they come before what can wait.
    case night
    /// A one-time flow (D92): something a person must decide once, at a calm time.
    case flow
    /// An offer to set something up (home, the heads-up, the gap): at a calm time, and it waits.
    case setup
    /// Last night, folded to one row: from the night's end until noon (D93).
    case review

    public static func < (lhs: Kind, rhs: Kind) -> Bool { lhs.rawValue < rhs.rawValue }
  }

  public enum Item: Hashable, Sendable {
    case screenTimeOff, readOnly, recovered, location
    case card(TonightCard)
    /// The answer to the heads-up offer's "Turn on" (#160), once: it's on and when it comes, or
    /// iOS's prompt was refused and only iOS Settings can allow it.
    case headsUpOn, headsUpDenied
    /// A one-time flow, by its id in `Flows.registry`.
    case flow(String)
    case lastNight

    public var kind: Kind {
      switch self {
      case .screenTimeOff, .readOnly, .recovered, .location: .problem
      case .card(let card): card.kind
      case .headsUpOn, .headsUpDenied: .setup
      case .flow: .flow
      case .lastNight: .review
      }
    }
  }

  /// What the band decides from: each item's own facts, already judged, and the night's times.
  /// The band adds only when each kind may show and which wins.
  public struct Facts: Equatable, Sendable {
    public var screenTimeOff = false
    public var readOnly = false
    public var recovered = false
    public var location = false
    /// The next lock, bed minus the gap (D76); nil with no night to come.
    public var nextLock: Date?
    /// The night is on now: locked, in the gap, paused, or inside its hours away from home.
    public var nightOn = false
    /// Any block on: no offers while anything is locked (D33).
    public var blocking = false
    public var entitled = true
    /// A night has ended since setup, so an offer has a reason (D68).
    public var nightEnded = false
    /// In the gap, with the helpers on and their card not answered (D80, D85).
    public var beforeBed = false
    /// Monday's gap card is unseen and still this week's night (D76).
    public var gapWeek = false
    /// The first setup offer due by its own facts: home, the heads-up, then the gap offer (D72).
    public var setup: TonightCard?
    /// iOS's answer just after the offer's "Turn on" (#160), held in memory until "OK" or the app
    /// goes to the background, so it shows once; nil at any other time.
    public var headsUpAnswer: NotificationPermission?
    /// The one-time flow due today, if any (`Flows.due`).
    public var flow: String?
    /// Last night can be reviewed (it ran, was away, or had Screen Time off) and the next night
    /// hasn't started; `lastNightPutAway` is its "OK" (D91).
    public var lastNight = false
    public var lastNightPutAway = false

    public init() {}
  }

  /// Top to bottom: at most one full card, then last night's row, nearest the strip.
  public var items: [Item]

  public init(items: [Item]) {
    self.items = items
  }

  public init(_ facts: Facts, now: Date, calendar: Calendar, config: TollConfig = .defaults) {
    let night = Self.nightOwns(facts, now: now, config: config)
    let card = Self.card(facts, calm: !night && !facts.blocking && facts.entitled)
    let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)
    let review =
      facts.lastNight && !facts.lastNightPutAway && !night && noon.map { now < $0 } == true
    items = [card, review ? .lastNight : nil].compactMap { $0 }
  }

  /// The one card, by kind. A calm time has no night, nothing locked, and isn't the hour before
  /// the lock.
  static func card(_ facts: Facts, calm: Bool) -> Item? {
    if facts.screenTimeOff { return .screenTimeOff }
    if facts.readOnly { return .readOnly }
    if facts.recovered { return .recovered }
    if facts.location { return .location }
    guard facts.entitled else { return nil }
    if facts.nightOn, facts.beforeBed { return .card(.beforeBed) }
    if facts.gapWeek, !facts.blocking, facts.nightEnded { return .card(.gapWeek) }
    guard calm else { return nil }
    // What the person just did is answered before anything new is offered.
    switch facts.headsUpAnswer {
    case .allowed?: return .headsUpOn
    case .denied?: return .headsUpDenied
    case .notAsked?, nil: break
    }
    if let flow = facts.flow { return .flow(flow) }
    if facts.nightEnded, let setup = facts.setup { return .card(setup) }
    return nil
  }

  /// From `band.nightMinutes` before the lock until the night ends, the band belongs to the night:
  /// only a problem or a card about the night shows, and last night's row is done.
  public static func nightOwns(_ facts: Facts, now: Date, config: TollConfig = .defaults) -> Bool {
    if facts.nightOn { return true }
    guard let lock = facts.nextLock else { return false }
    return lock.timeIntervalSince(now) <= TimeInterval(config.band.nightMinutes * 60)
  }

  public var card: Item? { items.first { $0 != .lastNight } }
  public var hasLastNight: Bool { items.contains(.lastNight) }
  public var isEmpty: Bool { items.isEmpty }
}

extension TonightCard {
  /// Before bed's card and Monday's are about the night; the rest are setup offers.
  public var kind: TonightBand.Kind {
    switch self {
    case .beforeBed, .gapWeek: .night
    case .home, .headsUp, .gapOffer: .setup
    }
  }
}
