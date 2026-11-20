import Foundation

/// Step 2's state file: one window, one home, one blocklist (schema 1). Only read, to migrate.
struct LegacyStateV1: Decodable {
  struct Settings: Decodable {
    var window: TimeWindow?
    var home: Home?
    var blocked: Data?
  }

  struct Home: Decodable {
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
  }

  struct OldPresence: Decodable {
    var isHome: Bool
    var at: Date
  }

  var settings: Settings
  var pending: Settings?
  var presence: OldPresence?
  var homeCheck: String?
  var setupFinishedAt: Date?
  var trialStart: Date?
  var purchased: Bool?
  var entitled: Bool?
  var blockOn: Bool?
  var blockEndsAt: Date?
  var lastNightEnd: Date?
  var clockAnchor: ClockAnchor?
  var door: Door?
  var unlocks: UnlockSupply?
  var doorAskedAt: Date?
}

enum Migration {
  static let homeID = PlaceID("home")
  static let sleepID = BlockID("sleep")

  /// Schema 1 becomes a Sleep block at a Home place (docs/architecture.md). Window schedules are left
  /// unset so the new ones replace step 2's. App counts are filled in by the app on its next launch;
  /// only it can open the selection.
  static func fromV1(_ old: LegacyStateV1) -> DuskState {
    var state = DuskState()
    guard let window = old.settings.window else { return state }
    let home = old.settings.home.map {
      Place(
        id: homeID, name: "Home", latitude: $0.latitude, longitude: $0.longitude,
        radiusMeters: $0.radiusMeters)
    }
    let sleep = Block(
      id: sleepID, name: "Sleep", kind: .sleep, place: home?.id,
      schedule: .everyDay(window), apps: old.settings.blocked)
    state.blocks = [sleep]
    state.places = home.map { [$0] } ?? []
    if let pending = old.pending, let window = pending.window {
      var edit = sleep
      edit.schedule = .everyDay(window)
      edit.apps = pending.blocked
      state.pending[sleep.id] = .save(edit)
    }
    if let presence = old.presence, let home {
      state.presence[home.id] = Presence(isInside: presence.isHome, at: presence.at)
    }
    state.location = old.homeCheck == "windowOnly" ? .scheduleOnly : .places
    state.setupFinishedAt = old.setupFinishedAt
    state.trial.start = old.trialStart
    state.trial.purchased = old.purchased ?? false
    state.trial.entitled = old.entitled ?? true
    if old.blockOn == true, let end = old.blockEndsAt { state.runtime.active[sleep.id] = end }
    state.runtime.lastEnd[sleep.id] = old.lastNightEnd
    state.runtime.clockAnchor = old.clockAnchor
    state.door = old.door
    state.unlocks = old.unlocks ?? UnlockSupply()
    state.doorAskedAt = old.doorAskedAt
    return state
  }
}

// Every stored type decodes missing keys as their defaults, so adding a field never makes an existing
// file unreadable.

extension DuskState {
  enum CodingKeys: String, CodingKey {
    case schema, blocks, places, presence, location, pending, pendingPlaces, door, doorAskedAt
    case doorAskedFor
    case unlocks, trial, setupFinishedAt, runtime, screenTimeAllowed
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init()
    schema = try c.decode(Int.self, forKey: .schema)
    blocks = try c.decodeIfPresent([Block].self, forKey: .blocks) ?? []
    places = try c.decodeIfPresent([Place].self, forKey: .places) ?? []
    presence = try c.decodeIfPresent([PlaceID: Presence].self, forKey: .presence) ?? [:]
    location = try c.decodeIfPresent(LocationMode.self, forKey: .location) ?? .places
    pending = try c.decodeIfPresent([BlockID: PendingEdit].self, forKey: .pending) ?? [:]
    pendingPlaces = try c.decodeIfPresent([PlaceID: Place].self, forKey: .pendingPlaces) ?? [:]
    door = try c.decodeIfPresent(Door.self, forKey: .door)
    doorAskedAt = try c.decodeIfPresent(Date.self, forKey: .doorAskedAt)
    doorAskedFor = try c.decodeIfPresent(Data.self, forKey: .doorAskedFor)
    unlocks = try c.decodeIfPresent(UnlockSupply.self, forKey: .unlocks) ?? UnlockSupply()
    trial = try c.decodeIfPresent(TrialState.self, forKey: .trial) ?? TrialState()
    setupFinishedAt = try c.decodeIfPresent(Date.self, forKey: .setupFinishedAt)
    runtime = try c.decodeIfPresent(RuntimeState.self, forKey: .runtime) ?? RuntimeState()
    screenTimeAllowed = try c.decodeIfPresent(Bool.self, forKey: .screenTimeAllowed)
  }
}

extension TrialState {
  enum CodingKeys: String, CodingKey { case start, purchased, entitled }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init()
    start = try c.decodeIfPresent(Date.self, forKey: .start)
    purchased = try c.decodeIfPresent(Bool.self, forKey: .purchased) ?? false
    entitled = try c.decodeIfPresent(Bool.self, forKey: .entitled) ?? true
  }
}

extension RuntimeState {
  enum CodingKeys: String, CodingKey {
    case active, lastEnd, clockAnchor, scheduledWindows, scheduledDoor
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init()
    active = try c.decodeIfPresent([BlockID: Date].self, forKey: .active) ?? [:]
    lastEnd = try c.decodeIfPresent([BlockID: Date].self, forKey: .lastEnd) ?? [:]
    clockAnchor = try c.decodeIfPresent(ClockAnchor.self, forKey: .clockAnchor)
    scheduledWindows = try c.decodeIfPresent([TimeWindow].self, forKey: .scheduledWindows)
    scheduledDoor = try c.decodeIfPresent(Date.self, forKey: .scheduledDoor)
  }
}

extension UnlockSupply {
  enum CodingKeys: String, CodingKey { case spent, cleanNights, countedThrough, lastSpendAt, used }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init()
    spent = try c.decodeIfPresent(Int.self, forKey: .spent) ?? 0
    cleanNights = try c.decodeIfPresent(Int.self, forKey: .cleanNights) ?? 0
    countedThrough = try c.decodeIfPresent(Date.self, forKey: .countedThrough)
    lastSpendAt = try c.decodeIfPresent(Date.self, forKey: .lastSpendAt)
    used = try c.decodeIfPresent(Int.self, forKey: .used) ?? 0
  }
}

extension Block {
  enum CodingKeys: String, CodingKey {
    case id, name, kind, place, schedule, apps, appCount, categoryCount, isOn
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      id: try c.decode(BlockID.self, forKey: .id),
      name: try c.decodeIfPresent(String.self, forKey: .name) ?? "",
      kind: try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .other,
      place: try c.decodeIfPresent(PlaceID.self, forKey: .place),
      schedule: try c.decode(WeeklySchedule.self, forKey: .schedule),
      apps: try c.decodeIfPresent(Data.self, forKey: .apps),
      appCount: try c.decodeIfPresent(Int.self, forKey: .appCount) ?? 0,
      categoryCount: try c.decodeIfPresent(Int.self, forKey: .categoryCount) ?? 0,
      isOn: try c.decodeIfPresent(Bool.self, forKey: .isOn) ?? true)
  }
}
