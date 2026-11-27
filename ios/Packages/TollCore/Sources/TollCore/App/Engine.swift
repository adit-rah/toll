import Foundation

/// The application layer's core (docs/architecture.md). `apply` turns a command into state;
/// `reconcile` decides what must be true now and returns the effects. Pure: the clock, the calendar
/// and the state come in, the state and the effects go out. Every process that wakes runs reconcile,
/// so whichever runs next corrects a callback that was missed (B-5).
public enum Engine {
  /// Launch and foreground run often and change nothing most times; only a change is worth a line.
  /// Every other cause is a wake the device protocol needs to see, changed or not.
  static let quietCauses: Set<ReconcileCause> = [.launch, .foreground]
  /// CLMonitor watches at most 20 conditions.
  static let maxPlaces = 20

  @discardableResult
  public static func apply(
    _ command: Command, to state: inout DuskState, now: Date, calendar: Calendar,
    config: TollConfig = .defaults
  ) -> CommandError? {
    switch command {
    case .finishSetup(let sleep, let home, let trialStart, let fit):
      guard sleep.isSleep else { return .noSleepBlock }
      guard sleep.schedule.isValid else { return .invalidSchedule }
      if let home { upsert(home, in: &state.places) }
      state.blocks.removeAll(where: \.isSleep)
      state.blocks.insert(sleep, at: 0)
      state.trial.start = state.trial.start ?? trialStart
      // A new install locks a gap before sleep from its first night (D76), and the buffer after
      // waking it chose (#144).
      if state.setupFinishedAt == nil {
        (state.gap, state.after) =
          fit.map { Fit.install($0, config: config) }
          ?? (.newInstall(config), .none(target: config.after.target))
        state.health = fit?.health ?? false
      }
      state.setupFinishedAt = now
    case .saveBlock(let block):
      if let error = validate(block, in: state, config: config) { return error }
      if state.runtime.active[block.id] != nil {
        state.pending[block.id] = .save(block)
      } else {
        upsert(block, in: &state.blocks)
        state.pending[block.id] = nil
      }
    case .deleteBlock(let id):
      guard state.block(id)?.isSleep != true else { return .sleepBlockCannotBeDeleted }
      if state.runtime.active[id] != nil {
        state.pending[id] = .delete
      } else {
        remove(id, from: &state)
      }
    case .savePlace(let place):
      let isNew = state.place(place.id) == nil
      if isNew && state.places.count >= maxPlaces { return .tooManyPlaces }
      if state.activeBlocks.contains(where: { $0.place == place.id }) {
        state.pendingPlaces[place.id] = place
      } else {
        movePlace(place, in: &state)
      }
    case .setHome(let place):
      return setHome(place, in: &state, now: now, calendar: calendar, config: config)
    case .useAnywhere:
      return useAnywhere(in: &state, now: now, calendar: calendar, config: config)
    case .dismissCard(let card):
      switch card {
      // Monday's card is this week's; next week's change shows again.
      case .gapWeek: GapRules.seen(&state)
      case .gapOffer: state.gap.offered = false
      default: state.dismissedCards.insert(card.rawValue)
      }
    case .putAwayLastNight(let night):
      state.lastNightSeen = night
    case .gap(let setting):
      GapRules.set(setting, &state, now: now, calendar: calendar, config: config)
    case .keepGap:
      GapRules.keep(&state, now: now, calendar: calendar, config: config)
    case .buffer(let side, let setting, let target):
      GapRules.set(
        side, setting, target: target, &state, now: now, calendar: calendar, config: config)
    case .fit(let fit):
      return Fit.apply(fit, to: &state, now: now, calendar: calendar, config: config)
    case .helpers(let helpers):
      state.helpers = helpers
      state.helpers.breathMinutes = helpers.breath(config)
    case .headsUp(let on):
      state.headsUp = on
    case .presence(let id, let presence):
      state.presence[id] = presence
    case .location(let mode):
      state.location = mode
    case .screenTime(let allowed):
      state.screenTimeAllowed = allowed
      if !allowed, state.setupFinishedAt != nil {
        state.gap.tally.screenTimeOff = true
        state.after.tally.screenTimeOff = true
      }
    case .trialStart(let start):
      state.trial.start = state.trial.start.map { min($0, start) } ?? start
    case .purchased(let purchased):
      state.trial.purchased = purchased
    case .startDoor:
      if let refusal = DoorRules.start(&state, now: now, calendar: calendar, config: config) {
        return .door(refusal)
      }
      // The ask is answered: once this pause ends, nothing reopens the sheet (#47).
      state.doorAskedAt = nil
    case .cancelDoor:
      DoorRules.cancel(&state)
      state.doorAskedAt = nil
    case .lockDoor:
      DoorRules.lockAgain(&state, now: now, calendar: calendar, config: config)
      state.doorAskedAt = nil
    case .askDoor(let at):
      state.doorAskedAt = at
    case .flow(let id, let version, let outcome):
      for next in Flows.record(id, version: version, outcome, in: &state, now: now, config: config)
      {
        _ = apply(next, to: &state, now: now, calendar: calendar, config: config)
      }
    }
    return nil
  }

  @discardableResult
  public static func reconcile(
    _ state: inout DuskState, wall: Date, monotonic: MonotonicInstant?, calendar: Calendar,
    cause: ReconcileCause, config: TollConfig = .defaults
  ) -> Effects {
    let before = state
    let now = trustedNow(&state, wall: wall, monotonic: monotonic)
    state.trial.entitled = Trial.isEntitled(state, now: now, calendar: calendar, config: config)
    noteEnds(&state, now: now, calendar: calendar)
    GapRules.advance(&state, now: now, calendar: calendar, config: config)
    var active = activeOccurrences(state, now: now, calendar: calendar)
    let edited = applyPending(&state, active: active)
    let gapChanged = GapRules.applyHeld(&state, active: active, now: now, calendar: calendar)
    if edited || gapChanged {
      noteEnds(&state, now: now, calendar: calendar)
      active = activeOccurrences(state, now: now, calendar: calendar)
    }
    state.runtime.active = active
    GapRules.tally(&state, now: now, calendar: calendar)
    DoorRules.advance(&state, now: now, calendar: calendar, config: config)
    return effects(
      before: before, after: &state, wall: wall, now: now, calendar: calendar, cause: cause)
  }

  // MARK: Deciding

  /// B-1, generalised (D29): a block is on when entitled, switched on, inside one of its occurrences,
  /// at its place (or it has none, or location is off, D37), and that occurrence began after the
  /// block's last end seen (B-4). The night's occurrences start the gap before bed (D76).
  static func activeOccurrences(_ state: DuskState, now: Date, calendar: Calendar)
    -> [BlockID: Date]
  {
    guard state.trial.entitled else { return [:] }
    var active: [BlockID: Date] = [:]
    for block in state.lockBlocks where block.isOn && isAtPlace(block, state) {
      guard let occurrence = block.schedule.occurrence(containing: now, calendar: calendar) else {
        continue
      }
      if let last = state.runtime.lastEnd[block.id], occurrence.start < last { continue }
      active[block.id] = occurrence.end
    }
    return active
  }

  static func isAtPlace(_ block: Block, _ state: DuskState) -> Bool {
    guard let place = block.place else { return true }
    // Without Always: on its hours anywhere (D37), unless the user chose to wait for Always (#63).
    guard state.location == .places else { return block.isSleep || !block.onlyAtPlace }
    return state.presence[place]?.isInside == true
  }

  /// Whether this block is held waiting for Always location (#63).
  public static func waitsForAlways(_ block: Block, _ state: DuskState) -> Bool {
    block.place != nil && !block.isSleep && block.onlyAtPlace && state.location != .places
  }

  /// During a block, the anchored time: setting the clock forward cannot end it, and setting it back
  /// cannot hold it past its real end (D12). With nothing on, the wall clock is taken and the anchor
  /// renewed. After a restart there is no anchor and the wall clock decides.
  static func trustedNow(_ state: inout DuskState, wall: Date, monotonic: MonotonicInstant?) -> Date
  {
    if !state.runtime.active.isEmpty, let anchored = state.runtime.clockAnchor?.now(monotonic) {
      return anchored
    }
    state.runtime.clockAnchor = monotonic.map { ClockAnchor(wall: wall, monotonic: $0) }
    return wall
  }

  /// Only ever moves forward: a clock set back must not make an ended occurrence look unfinished.
  static func noteEnds(_ state: inout DuskState, now: Date, calendar: Calendar) {
    var ends: [BlockID: Date] = [:]
    for block in state.lockBlocks {
      let latest = block.schedule.lastEnd(atOrBefore: now, calendar: calendar)
      ends[block.id] = [state.runtime.lastEnd[block.id], latest].compactMap { $0 }.max()
    }
    state.runtime.lastEnd = ends
  }

  /// B-3: held edits of blocks that are no longer on, and held moves of places no active block uses.
  static func applyPending(_ state: inout DuskState, active: [BlockID: Date]) -> Bool {
    var changed = false
    for (id, edit) in state.pending where active[id] == nil {
      switch edit {
      case .save(let block): upsert(block, in: &state.blocks)
      case .delete: remove(id, from: &state)
      }
      state.pending[id] = nil
      changed = true
    }
    let usedPlaces = Set(state.blocks.filter { active[$0.id] != nil }.compactMap(\.place))
    for (id, place) in state.pendingPlaces where !usedPlaces.contains(id) {
      movePlace(place, in: &state)
      state.pendingPlaces[id] = nil
      changed = true
    }
    return changed
  }

  // MARK: Effects

  static func effects(
    before: DuskState, after state: inout DuskState, wall: Date, now: Date, calendar: Calendar,
    cause: ReconcileCause
  ) -> Effects {
    let active = state.activeBlocks
    // A pause lifts every block's shield at once (D67); reconcile puts it back when the pause ends.
    let paused = state.door?.phase == .open
    var effects = Effects(
      shield: active.isEmpty || paused ? .off : ShieldPlan(selections: active.compactMap(\.apps)),
      places: state.location == .places ? state.places : [])
    let windows = scheduledWindows(state.lockBlocks)
    if state.runtime.scheduledWindows != windows {
      state.runtime.scheduledWindows = windows
      effects.windows = windows
    }
    // Compared with what was scheduled, not with the state before: the command that opened the door
    // ran just before this reconcile.
    if let door = state.door, state.runtime.scheduledDoor != door.waitEndsAt {
      state.runtime.scheduledDoor = door.waitEndsAt
      effects.door = .start(door)
    } else if state.door == nil, state.runtime.scheduledDoor != nil {
      state.runtime.scheduledDoor = nil
      effects.door = .stop
    }
    let changed =
      Set(before.runtime.active.keys) != Set(state.runtime.active.keys)
      || before.door?.phase != state.door?.phase
    if changed || !quietCauses.contains(cause) {
      let sleepPlace = state.sleepBlock?.place
      effects.log = Transition(
        at: wall, cause: cause, blockOn: state.isBlocking, changed: changed,
        home: sleepPlace.flatMap { state.presence[$0]?.isInside },
        inWindow: state.lockSleep?.schedule.occurrence(containing: now, calendar: calendar) != nil,
        entitled: state.trial.entitled, door: state.door?.phase,
        active: state.runtime.active.keys.sorted(), screenTime: state.screenTimeAllowed)
    }
    return effects
  }

  /// One schedule per distinct window across the blocks that are on, in a fixed order.
  static func scheduledWindows(_ blocks: [Block]) -> [TimeWindow] {
    Array(Set(blocks.filter(\.isOn).flatMap(\.schedule.windows)))
      .sorted {
        ($0.start.minuteOfDay, $0.end.minuteOfDay) < ($1.start.minuteOfDay, $1.end.minuteOfDay)
      }
  }

  // MARK: Edits

  static func validate(_ block: Block, in state: DuskState, config: TollConfig) -> CommandError? {
    guard block.schedule.isValid else { return .invalidSchedule }
    if !block.isSleep, !BlockDraft.isValidName(block.name, config: config) { return .invalidName }
    let others = state.blocks.filter { $0.id != block.id }
    if block.isSleep, others.contains(where: \.isSleep) { return .noSleepBlock }
    if others.count + 1 > config.blocks.max { return .tooManyBlocks }
    if others.map(\.appCount).reduce(block.appCount, +) > config.blocks.maxApps {
      return .tooManyApps
    }
    if scheduledWindows((others + [block]).map(state.locking)).count > config.blocks.maxWindows {
      return .tooManyWindows
    }
    if let place = block.place, state.place(place) == nil, state.pendingPlaces[place] == nil {
      return .unknownPlace
    }
    return nil
  }

  static func upsert(_ block: Block, in blocks: inout [Block]) {
    if let index = blocks.firstIndex(where: { $0.id == block.id }) {
      blocks[index] = block
    } else {
      blocks.append(block)
    }
  }

  static func upsert(_ place: Place, in places: inout [Place]) {
    if let index = places.firstIndex(where: { $0.id == place.id }) {
      places[index] = place
    } else {
      places.append(place)
    }
  }

  /// A moved region forgets its presence: the monitor reports afresh for the new circle.
  static func movePlace(_ place: Place, in state: inout DuskState) {
    if let old = state.place(place.id), !old.sameRegion(as: place) {
      state.presence[place.id] = nil
    }
    upsert(place, in: &state.places)
  }

  static func remove(_ id: BlockID, from state: inout DuskState) {
    state.blocks.removeAll { $0.id == id }
    state.runtime.lastEnd[id] = nil
    state.pending[id] = nil
  }
}
