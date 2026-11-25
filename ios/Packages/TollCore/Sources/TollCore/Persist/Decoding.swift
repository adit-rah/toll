import Foundation

// Every stored type decodes lossily (`Lossy.swift`): a missing key takes its default, so adding a
// field never makes an existing file unreadable, and a value that can't be read falls back or is
// dropped on its own. Only what identifies a thing (an id, a place's centre, a window's times) is
// required; without it the element is dropped, never the file.

extension DuskState {
  enum CodingKeys: String, CodingKey {
    case schema, minReader, writtenBy, blocks, places, presence, location, pending, pendingPlaces
    case door, doorAskedAt, unlocks, trial, setupFinishedAt, runtime, screenTimeAllowed
    case dismissedCards, lastNightSeen, headsUp, gap, after, health, helpers, flows, recoveredAt
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init()
    schema = c.lossy(.schema, or: DuskState.schema)
    minReader = c.lossy(.minReader, or: schema)
    writtenBy = c.lossy(.writtenBy)
    blocks = c.lossyArray(.blocks)
    places = c.lossyArray(.places)
    presence = c.lossyMap(.presence)
    location = c.lossy(.location, or: .places)
    pending = c.lossyMap(.pending)
    pendingPlaces = c.lossyMap(.pendingPlaces)
    door = c.lossy(.door)
    doorAskedAt = c.lossy(.doorAskedAt)
    unlocks = c.lossy(.unlocks, or: UnlockSupply())
    trial = c.lossy(.trial, or: TrialState())
    setupFinishedAt = c.lossy(.setupFinishedAt)
    runtime = c.lossy(.runtime, or: RuntimeState())
    screenTimeAllowed = c.lossy(.screenTimeAllowed)
    dismissedCards = c.lossySet(.dismissedCards)
    lastNightSeen = c.lossy(.lastNightSeen)
    headsUp = c.lossy(.headsUp, or: true)
    gap = c.lossy(.gap, or: Gap())
    after = c.lossy(.after, or: Gap.none(target: TollConfig.defaults.after.target))
    health = c.lossy(.health, or: false)
    helpers = c.lossy(.helpers, or: Helpers())
    flows = c.lossyMap(.flows)
    recoveredAt = c.lossy(.recoveredAt)
  }
}

extension TrialState {
  enum CodingKeys: String, CodingKey { case start, purchased, entitled }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init()
    start = c.lossy(.start)
    purchased = c.lossy(.purchased, or: false)
    entitled = c.lossy(.entitled, or: true)
  }
}

extension RuntimeState {
  enum CodingKeys: String, CodingKey {
    case active, lastEnd, clockAnchor, scheduledWindows, scheduledDoor
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init()
    active = c.lossyMap(.active)
    lastEnd = c.lossyMap(.lastEnd)
    clockAnchor = c.lossy(.clockAnchor)
    // All or nothing: a partial list would leave a schedule unregistered; nil registers them again.
    scheduledWindows = c.lossy(.scheduledWindows)
    scheduledDoor = c.lossy(.scheduledDoor)
  }
}

extension UnlockSupply {
  enum CodingKeys: String, CodingKey { case spent, week, used }

  /// A supply from before D67 has no week, so it starts the current one full.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init()
    spent = c.lossy(.spent, or: 0)
    week = c.lossy(.week)
    used = c.lossy(.used, or: 0)
  }
}

extension Block {
  enum CodingKeys: String, CodingKey {
    case id, name, kind, place, schedule, apps, appCount, categoryCount, isOn, onlyAtPlace
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      id: try c.decode(BlockID.self, forKey: .id),
      name: c.lossy(.name, or: ""),
      kind: c.lossy(.kind, or: .other),
      place: c.lossy(.place),
      schedule: try c.decode(WeeklySchedule.self, forKey: .schedule),
      apps: c.lossy(.apps),
      appCount: c.lossy(.appCount, or: 0),
      categoryCount: c.lossy(.categoryCount, or: 0),
      isOn: c.lossy(.isOn, or: true),
      onlyAtPlace: c.lossy(.onlyAtPlace, or: false))
  }
}

extension Block.Kind {
  /// A kind from a newer build is a plain block: the Sleep block's kind never changes.
  public init(from decoder: Decoder) throws { self = try decoder.raw(or: .other) }
}

extension LocationMode {
  /// Hours alone: nothing paid depends on a place this build can't name (D37).
  public init(from decoder: Decoder) throws { self = try decoder.raw(or: .scheduleOnly) }
}

extension Gap.Mode {
  /// Fixed: the gap stays where it is rather than following a rule this build doesn't know.
  public init(from decoder: Decoder) throws { self = try decoder.raw(or: .fixed) }
}

extension WeeklySchedule {
  enum CodingKeys: String, CodingKey { case rules }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let rules: [Rule] = c.lossyArray(.rules)
    guard !rules.isEmpty else {
      throw DecodingError.dataCorruptedError(
        forKey: .rules, in: c, debugDescription: "no rule could be read")
    }
    self.init(rules: rules)
  }
}

extension WeeklySchedule.Rule {
  enum CodingKeys: String, CodingKey { case days, window }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let days: Set<Weekday> = c.lossySet(.days)
    guard !days.isEmpty else {
      throw DecodingError.dataCorruptedError(
        forKey: .days, in: c, debugDescription: "no day could be read")
    }
    self.init(days: days, window: try c.decode(TimeWindow.self, forKey: .window))
  }
}

extension Place {
  enum CodingKeys: String, CodingKey { case id, name, latitude, longitude, radiusMeters }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      id: try c.decode(PlaceID.self, forKey: .id),
      name: c.lossy(.name, or: ""),
      latitude: try c.decode(Double.self, forKey: .latitude),
      longitude: try c.decode(Double.self, forKey: .longitude),
      radiusMeters: c.lossy(.radiusMeters, or: TollConfig.defaults.home.radiusMeters))
  }
}

extension Door {
  enum CodingKeys: String, CodingKey { case waitEndsAt, openedAt, expiresAt }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(waitEndsAt: try c.decode(Date.self, forKey: .waitEndsAt))
    openedAt = c.lossy(.openedAt)
    expiresAt = c.lossy(.expiresAt)
  }
}

extension Gap {
  enum CodingKeys: String, CodingKey {
    case minutes, mode, target, pending, streak, eased, frozenThrough, tally, change, offered
    case history
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init()
    minutes = c.lossy(.minutes, or: 0)
    mode = c.lossy(.mode, or: .fixed)
    // A buffer from before #144 had D76's one target; schema 4's step writes it in.
    target = c.lossy(.target, or: TollConfig.defaults.gap.cap)
    pending = c.lossy(.pending)
    streak = c.lossy(.streak, or: 0)
    eased = c.lossy(.eased, or: false)
    frozenThrough = c.lossy(.frozenThrough)
    tally = c.lossy(.tally, or: Tally())
    change = c.lossy(.change)
    offered = c.lossy(.offered, or: false)
    history = c.lossyArray(.history)
  }
}

extension Gap.Tally {
  enum CodingKeys: String, CodingKey { case week, nights, pausesInGap, screenTimeOff }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(week: c.lossy(.week))
    nights = c.lossySet(.nights)
    pausesInGap = c.lossy(.pausesInGap, or: 0)
    screenTimeOff = c.lossy(.screenTimeOff, or: false)
  }
}

extension Gap.Change {
  enum CodingKeys: String, CodingKey { case week, from, to, seen }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      week: try c.decode(Date.self, forKey: .week), from: try c.decode(Int.self, forKey: .from),
      to: try c.decode(Int.self, forKey: .to))
    seen = c.lossy(.seen, or: false)
  }
}

extension Helpers {
  enum CodingKeys: String, CodingKey { case on, breathMinutes }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(on: c.lossy(.on, or: true), breathMinutes: c.lossy(.breathMinutes))
  }
}
