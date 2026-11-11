import Foundation
import TollCore

#if os(iOS)
  import TollScreenTime
#endif

/// The app side of the gate (spec §11.1 "App launch and foreground"). Owns the transitions; the shared
/// state file is the source of truth so the monitor and the shields see the same thing.
public actor GateService {
  let store: LocalStore
  let sync: SyncEngine
  let gateStore: SharedGateStore
  let clock: any TollClock
  let analytics: Analytics
  var config: TollConfig

  public init(
    store: LocalStore, sync: SyncEngine, config: TollConfig, clock: any TollClock = SystemClock(),
    gateStore: SharedGateStore = SharedGateStore(), analytics: Analytics = .disabled
  ) {
    self.store = store
    self.sync = sync
    self.config = config
    self.clock = clock
    self.gateStore = gateStore
    self.analytics = analytics
  }

  public func update(config: TollConfig) { self.config = config }

  var machine: GateMachine { GateMachine(config: config.gate, timeZone: clock.timeZone) }
  var math: DayMath { DayMath(timeZone: clock.timeZone, resetHour: config.gate.dayResetHour) }

  public var state: SharedGateState { gateStore.load() }

  /// Everything that must happen whenever Toll comes to the front, or wakes in the background with
  /// `userOpened` false. Returns the state to render.
  @discardableResult
  public func foreground(userOpened: Bool = true) async -> SharedGateState {
    let now = clock.now
    let ingested = await SpoolIngester(store: store).ingest()
    await reconcileShield(now: now, source: "foreground")
    var events: [GateEvent] = []
    var entered: Entered?
    let ledger = await todayLedger()
    await checkInIfNeeded(now: now)
    gateStore.update { state in
      machine.expireStalePass(state: &state, now: now)
      events += machine.tick(state: &state, now: now, monotonic: clock.monotonic)
      if let hit = ingested.latestOpenHit, let ref = hit.appRef,
        hit.occurredAt > (state.pendingHit?.at ?? .distantPast)
      {
        state.pendingHit = PendingHit(appRef: ref, at: hit.occurredAt)
      }
      if userOpened, let hit = state.pendingHit {
        state.pendingHit = nil
        if now.timeIntervalSince(hit.at) <= TimeInterval(config.gate.resumeWindowSeconds) {
          let before = state
          let started = machine.enter(
            appRef: hit.appRef, ledger: ledger, state: &state, now: now, monotonic: clock.monotonic)
          entered = Entered(before: before, after: state, events: started)
          events += started
        }
      }
    }
    try? await store.record(events)
    send(entered)
    await refreshShieldCounts()
    if userOpened {
      // The wait card is drawn from the state returned here, so it must not sit behind a network round
      // trip. Background wakes still wait: they are suspended as soon as this returns.
      flushSoon()
    } else {
      await sync.flush()
    }
    return gateStore.load()
  }

  /// Unblock inside Toll (G-3): the gate a shield hit enters, for the whole block, with no `block_hit`.
  public func requestUnblock(block: BlockRef) async -> SharedGateState {
    let now = clock.now
    var events: [GateEvent] = []
    var entered: Entered?
    let ledger = await todayLedger()
    gateStore.update { state in
      machine.expireStalePass(state: &state, now: now)
      events += machine.tick(state: &state, now: now, monotonic: clock.monotonic)
      guard let definition = state.blocks.first(where: { $0.id == block }) else { return }
      let before = state
      let started = machine.enter(
        block: definition, ledger: ledger, state: &state, now: now, monotonic: clock.monotonic)
      entered = Entered(before: before, after: state, events: started)
      events += started
    }
    try? await store.record(events)
    send(entered)
    if !events.isEmpty { flushSoon() }
    return gateStore.load()
  }

  /// Called every second while the wait card is up so it turns into the session picker at zero (G-4).
  public func tick() async -> SharedGateState {
    var events: [GateEvent] = []
    let current = gateStore.update { state in
      events = machine.tick(state: &state, now: clock.now, monotonic: clock.monotonic)
    }
    // A wait that is still running changed nothing, so the state just read is the answer.
    guard !events.isEmpty else { return current }
    try? await store.record(events)
    flushSoon()
    return current
  }

  public func cancelWait() async -> SharedGateState {
    var events: [GateEvent] = []
    gateStore.update { state in events = machine.cancelWait(state: &state, now: clock.now) }
    try? await store.record(events)
    if !events.isEmpty { analytics.send(.waitAbandoned) }
    return gateStore.load()
  }

  /// "Not now" on a pass that came from a shield: kept for the day, with the picker off screen.
  public func deferPendingPass() async -> SharedGateState {
    gateStore.update { machine.deferPass(state: &$0) }
  }

  /// Shows the picker again for a pass that was set aside.
  public func resumePendingPass() async -> SharedGateState {
    let now = clock.now
    return gateStore.update { state in
      machine.expireStalePass(state: &state, now: now)
      machine.resumePass(state: &state)
    }
  }

  /// "Not now" on a pass asked for inside Toll: dropped. No `pass` was recorded, so it costs nothing.
  public func discardPendingPass() async -> SharedGateState {
    gateStore.update { machine.discardPass(state: &$0) }
  }

  /// The session picker's button: unlocks the pending apps for the chosen minutes from now and records
  /// the pass, which counts from the moment it is used (G-6, G-7).
  public func startSession(minutes: Int) async -> ActiveSession? {
    let now = clock.now
    var start: (session: ActiveSession, pass: GateEvent)?
    gateStore.update { state in
      machine.expireStalePass(state: &state, now: now)
      start = machine.startSession(minutes: minutes, state: &state, now: now)
    }
    guard let start else { return nil }
    try? await store.record([start.pass])
    await reconcileShield(now: now, source: "session-start")
    #if os(iOS)
      do {
        try ActivityScheduler().start(session: start.session, calendar: math.calendar)
      } catch {
        // Without the activity nothing wakes the monitor; the persisted expiry still ends the session
        // on the next reconcile (G-6).
        Log.gate.error("session activity failed: \(error.localizedDescription, privacy: .public)")
      }
    #endif
    await refreshShieldCounts()
    // Not awaited: the user is on their way to the app, not waiting for an upload.
    flushSoon(force: true)
    return start.session
  }

  /// "Block again": ends a session before its time and puts the shield back.
  public func endSession(_ id: UUID) async -> SharedGateState {
    let now = clock.now
    var ended: ActiveSession?
    gateStore.update { state in ended = machine.endSession(id, state: &state) }
    guard let ended else { return gateStore.load() }
    try? await store.record([machine.sessionEnded(ended, at: now)])
    await reconcileShield(now: now, source: "block-again")
    #if os(iOS)
      ActivityScheduler().stop(sessions: [ended])
    #endif
    flushSoon()
    return gateStore.load()
  }

  /// Cheap enough to call when a countdown reaches zero: ends sessions past their expiry and re-shields.
  public func expireSessions() async -> SharedGateState {
    if await reconcileShield(now: clock.now, source: "expiry") { flushSoon() }
    return gateStore.load()
  }

  /// Ends sessions past their expiry, applies the shield and records `session_ended` for each (G-6).
  /// Returns whether any ended.
  @discardableResult
  private func reconcileShield(now: Date, source: String) async -> Bool {
    #if os(iOS)
      let ended = ShieldReconciler().reconcile(now: now, timeZone: clock.timeZone, source: source)
      try? await store.record(ended.map { machine.sessionEnded($0, at: now) })
      return !ended.isEmpty
    #else
      return false
    #endif
  }

  /// What one entry to the gate did, for `gate_entered`. Granting a pass records no event, so the
  /// free path is read from the state the entry left behind.
  private struct Entered {
    var grantedFree: Bool
    var startedWait: Bool

    init(before: SharedGateState, after: SharedGateState, events: [GateEvent]) {
      grantedFree = before.pendingPass == nil && after.pendingPass?.free == true
      startedWait = events.contains { $0.kind == .waitStarted }
    }
  }

  private func send(_ entered: Entered?) {
    guard let entered else { return }
    if entered.grantedFree {
      analytics.send(.gateEntered(free: true))
    } else if entered.startedWait {
      analytics.send(.gateEntered(free: false))
    }
  }

  /// For work the user is watching: the state is returned first and the upload follows.
  private func flushSoon(force: Bool = false) {
    Task { [sync] in await sync.flush(force: force) }
  }

  public func todayLedger() async -> GateLedger {
    let day = math.day(containing: clock.now)
    let events = (try? await store.events(from: math.start(of: day), to: math.end(of: day))) ?? []
    return GateLedger(eventsOfToday: events)
  }

  /// The monitor checks in at midnight, which a phone that was off misses; Toll opening is proof too, so
  /// friends never see a false silence (N-9).
  func checkInIfNeeded(now: Date) async {
    guard !gateStore.load().blocks.isEmpty else { return }
    let day = math.day(containing: now)
    let today = (try? await store.events(from: math.start(of: day), to: math.end(of: day))) ?? []
    guard !today.contains(where: { $0.kind == .checkin }) else { return }
    try? await store.record([
      GateEvent(kind: .checkin, occurredAt: now, tzOffsetMinutes: GateEvent.offsetMinutes(at: now, in: clock.timeZone))
    ])
  }

  public func setNotificationsAllowed(_ allowed: Bool) {
    gateStore.update { $0.notificationsAllowed = allowed }
  }

  /// Keeps the shield subtitle's per-app count and the reset hour current for the extensions.
  func refreshShieldCounts() async {
    let ledger = await todayLedger()
    gateStore.update { machine.refreshUnblocks(state: &$0, ledger: ledger, now: clock.now) }
  }
}
