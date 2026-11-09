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
    #if os(iOS)
      let ended = ShieldReconciler().reconcile(now: now, timeZone: clock.timeZone, source: "foreground")
      try? await store.record(ended.map { machine.sessionEnded($0, at: now) })
    #endif
    var events: [GateEvent] = []
    let ledger = await todayLedger()
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
          events += machine.enter(
            appRef: hit.appRef, ledger: ledger, state: &state, now: now, monotonic: clock.monotonic)
        }
      }
    }
    try? await store.record(events)
    if events.contains(where: { $0.kind == .pass && $0.free == true }) {
      analytics.send(.gateEntered(free: true))
    } else if events.contains(where: { $0.kind == .waitStarted }) {
      analytics.send(.gateEntered(free: false))
    }
    await refreshShieldCounts()
    if events.contains(where: { $0.kind == .pass }) { await sync.flush(force: true) } else { await sync.flush() }
    return gateStore.load()
  }

  /// Called every second while the wait card is up so it turns into the session picker at zero (G-4).
  public func tick() async -> SharedGateState {
    var events: [GateEvent] = []
    gateStore.update { state in events = machine.tick(state: &state, now: clock.now, monotonic: clock.monotonic) }
    if !events.isEmpty {
      try? await store.record(events)
      await refreshShieldCounts()
      await sync.flush(force: true)
    }
    return gateStore.load()
  }

  public func cancelWait() async -> SharedGateState {
    var events: [GateEvent] = []
    gateStore.update { state in events = machine.cancelWait(state: &state, now: clock.now) }
    try? await store.record(events)
    if !events.isEmpty { analytics.send(.waitAbandoned) }
    return gateStore.load()
  }

  /// The session picker's Open: unlock the pending apps and start the threshold activity (G-6).
  public func startSession(minutes: Int) async -> ActiveSession? {
    var session: ActiveSession?
    let now = clock.now
    gateStore.update { state in session = machine.startSession(minutes: minutes, state: &state, now: now) }
    guard let session else { return nil }
    #if os(iOS)
      let reconciler = ShieldReconciler()
      reconciler.reconcile(now: now, timeZone: clock.timeZone, source: "session-start")
      do {
        try ActivityScheduler().start(
          session: session, tokens: reconciler.registry.tokens(for: session.appRefs), calendar: math.calendar)
      } catch {
        // Without the threshold activity the persisted expiry still ends the session (G-6).
        Log.gate.error("session activity failed: \(error.localizedDescription, privacy: .public)")
      }
    #endif
    return session
  }

  public func todayLedger() async -> GateLedger {
    let day = math.day(containing: clock.now)
    let events = (try? await store.events(from: math.start(of: day), to: math.end(of: day))) ?? []
    return GateLedger(eventsOfToday: events)
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
