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
      id: sleepID, name: Copy.Setup.nightName, kind: .sleep, place: home?.id,
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
    state.gap = .existing
    state.after.offered = true
    return state
  }
}

extension Migration {
  /// One step from a schema to the next, on the file's JSON as it was written. A step never reads
  /// today's types, so a later change to `Block` can't break reading an old file; the fixtures in
  /// `Tests/TollCoreTests/Fixtures/state` are the frozen shapes each step starts from.
  struct Step: Sendable {
    let from: Int
    let run: @Sendable ([String: Any]) -> [String: Any]
  }

  static let steps: [Step] = [Step(from: 2, run: v2to3), Step(from: 3, run: v3to4)]

  /// Every step from `schema` to the current one, in order.
  static func upgrade(_ object: [String: Any], from schema: Int) -> [String: Any] {
    steps.filter { $0.from >= schema }.sorted { $0.from < $1.from }.reduce(object) { $1.run($0) }
  }

  /// 2 to 3: a file without a gap is from before D76. It keeps its night as it was and is offered
  /// the gap once. That was a decoder's default, and a default must never carry a decision.
  @Sendable static func v2to3(_ old: [String: Any]) -> [String: Any] {
    var new = old
    if new["gap"] == nil { new["gap"] = ["offered": true] }
    if new["flows"] == nil { new["flows"] = [String: Any]() }
    new["schema"] = 3
    new["minReader"] = 2
    return new
  }

  /// 3 to 4 (#144): the stored night is now the person's sleep, and the lock adds a buffer each
  /// side. Their night stays as it was: sleep is the hours they set, the buffer before is their
  /// gap, growing toward D76's 60 as it did, and there's no buffer after. The one-time flow "Fit
  /// Dusk to your sleep" offers it once (`offered`).
  @Sendable static func v3to4(_ old: [String: Any]) -> [String: Any] {
    var new = old
    var gap = new["gap"] as? [String: Any] ?? [:]
    if gap["target"] == nil { gap["target"] = TollConfig.defaults.gap.cap }
    new["gap"] = gap
    if new["after"] == nil {
      new["after"] =
        [
          "minutes": 0, "mode": Gap.Mode.fixed.rawValue,
          "target": TollConfig.defaults.after.target, "offered": true,
        ] as [String: Any]
    }
    if new["health"] == nil { new["health"] = false }
    new["schema"] = 4
    new["minReader"] = 4
    return new
  }
}
