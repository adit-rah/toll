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
    _ command: Command, to state: inout DuskState, now: Date, config: TollConfig = .defaults
  ) -> CommandError? {
    switch command {
    case .finishSetup(let sleep, let home, let trialStart):
      guard sleep.isSleep else { return .noSleepBlock }
      guard sleep.schedule.isValid else { return .invalidSchedule }
      if let home { upsert(home, in: &state.places) }
      state.blocks.removeAll(where: \.isSleep)
      state.blocks.insert(sleep, at: 0)
      state.trial.start = state.trial.start ?? trialStart
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
    case .presence(let id, let presence):
      state.presence[id] = presence
    case .location(let mode):
      state.location = mode
    case .trialStart(let start):
      state.trial.start = state.trial.start.map { min($0, start) } ?? start
    case .purchased(let purchased):
      state.trial.purchased = purchased
    case .startDoor(let app):
      if let refusal = DoorRules.start(&state, app: app, now: now, config: config) {
        return .door(refusal)
      }
      // The ask is answered: once this door ends, nothing reopens the choice (#47).
      clearAsk(&state)
    case .cancelDoor:
      DoorRules.cancel(&state)
      clearAsk(&state)
    case .lockDoor:
      DoorRules.lockAgain(&state, now: now, config: config)
      clearAsk(&state)
    case .askDoor(let at, let app):
      state.doorAskedAt = at
      state.doorAskedFor = at == nil ? nil : app
    }
    return nil
  }

  static func clearAsk(_ state: inout DuskState) {
    state.doorAskedAt = nil
    state.doorAskedFor = nil
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
    var active = activeOccurrences(state, now: now, calendar: calendar)
    if applyPending(&state, active: active) {
      noteEnds(&state, now: now, calendar: calendar)
      active = activeOccurrences(state, now: now, calendar: calendar)
    }
    state.runtime.active = active
    DoorRules.advance(&state, now: now, config: config)
    DoorRules.countNights(&state, now: now, calendar: calendar, config: config)
    return effects(
      before: before, after: &state, wall: wall, now: now, calendar: calendar, cause: cause)
  }

  // MARK: Deciding

  /// B-1, generalised (D29): a block is on when entitled, switched on, inside one of its occurrences,
  /// at its place (or it has none, or location is off, D37), and that occurrence began after the
  /// block's last end seen (B-4).
  static func activeOccurrences(_ state: DuskState, now: Date, calendar: Calendar)
    -> [BlockID: Date]
  {
    guard state.trial.entitled else { return [:] }
    var active: [BlockID: Date] = [:]
    for block in state.blocks where block.isOn && isAtPlace(block, state) {
      guard let occurrence = block.schedule.occurrence(containing: now, calendar: calendar) else {
        continue
      }
      if let last = state.runtime.lastEnd[block.id], occurrence.start < last { continue }
      active[block.id] = occurrence.end
    }
    return active
  }

  static func isAtPlace(_ block: Block, _ state: DuskState) -> Bool {
    guard let place = block.place, state.location == .places else { return true }
    return state.presence[place]?.isInside == true
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
    for block in state.blocks {
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
    var effects = Effects(
      shield: active.isEmpty
        ? .off
        : ShieldPlan(
          selections: active.compactMap(\.apps),
          doorApp: state.door?.phase == .open ? state.door?.app : nil),
      places: state.location == .places ? state.places : [])
    let windows = scheduledWindows(state.blocks)
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
        inWindow: state.sleepBlock?.schedule.occurrence(containing: now, calendar: calendar) != nil,
        entitled: state.trial.entitled, door: state.door?.phase,
        active: state.runtime.active.keys.sorted())
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
    let others = state.blocks.filter { $0.id != block.id }
    if block.isSleep, others.contains(where: \.isSleep) { return .noSleepBlock }
    if others.count + 1 > config.blocks.max { return .tooManyBlocks }
    if others.map(\.appCount).reduce(block.appCount, +) > config.blocks.maxApps {
      return .tooManyApps
    }
    if scheduledWindows(others + [block]).count > config.blocks.maxWindows {
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
