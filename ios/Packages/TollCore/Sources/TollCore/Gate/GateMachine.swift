import Foundation

/// The gate's transitions (G-3…G-7). Pure: each call mutates the shared state and returns the events to
/// record; the caller applies shields and persists. One open request at a time.
public struct GateMachine: Sendable {
  public let config: TollConfig.Gate
  public let timeZone: TimeZone

  public init(config: TollConfig.Gate, timeZone: TimeZone) {
    self.config = config
    self.timeZone = timeZone
  }

  private var tolerance: TimeInterval { TimeInterval(config.clockSkewToleranceSeconds) }

  private func event(_ kind: GateEvent.Kind, at date: Date) -> GateEvent {
    GateEvent(
      kind: kind, occurredAt: date, tzOffsetMinutes: GateEvent.offsetMinutes(at: date, in: timeZone)
    )
  }

  /// Toll opened from a shield for `appRef` (G-3). A pending pass or a running wait absorbs the hit (G-5).
  public func enter(
    appRef: AppRef, ledger: GateLedger, state: inout SharedGateState, now: Date,
    monotonic: MonotonicInstant?
  ) -> [GateEvent] {
    let blockRef = state.blocks.first { $0.appRefs.contains(appRef) }?.id
    return request(
      [appRef], origin: .shield, blockRef: blockRef, ledger: ledger, state: &state, now: now,
      monotonic: monotonic)
  }

  /// Unblock inside Toll (G-3): the same gate as a shield hit, for every app in the block at once.
  /// The caller records no `block_hit`, because nothing was hit.
  public func enter(
    block: BlockDefinition, ledger: GateLedger, state: inout SharedGateState, now: Date,
    monotonic: MonotonicInstant?
  ) -> [GateEvent] {
    request(
      block.appRefs, origin: .app, blockRef: block.id, ledger: ledger, state: &state, now: now,
      monotonic: monotonic)
  }

  /// Granting a pass records nothing: it becomes a `pass` event only when it is used
  /// (`startSession`), so one that is discarded or lapses costs neither a free pass nor a step on
  /// the wait ladder.
  private func request(
    _ refs: [AppRef], origin: PendingPass.Origin, blockRef: BlockRef?, ledger: GateLedger,
    state: inout SharedGateState, now: Date, monotonic: MonotonicInstant?
  ) -> [GateEvent] {
    guard let primary = refs.first else { return [] }
    if var pending = state.pendingPass {
      for ref in refs where !pending.appRefs.contains(ref) { pending.appRefs.append(ref) }
      pending.deferred = false
      state.pendingPass = pending
      return []
    }
    switch GateRules.entry(ledger: ledger, runningWait: state.wait, config: config) {
    case .joinWait:
      state.wait?.join(refs)
      return []
    case .freePass:
      state.pendingPass = PendingPass(
        appRefs: refs, free: true, waitMinutes: 0, grantedAt: now, origin: origin,
        blockRef: blockRef)
      return []
    case .startWait(let minutes, let number):
      state.wait = Wait(
        appRefs: refs, number: number, minutes: minutes, startedAt: now,
        startedMonotonic: monotonic, origin: origin, blockRef: blockRef)
      var started = event(.waitStarted, at: now)
      started.appRef = primary
      started.waitMinutes = minutes
      return [started]
    }
  }

  /// Turns a finished wait into a pending waited pass. Called whenever Toll is in front (G-4: the user
  /// comes back when they come back; nothing notifies them).
  public func tick(state: inout SharedGateState, now: Date, monotonic: MonotonicInstant?)
    -> [GateEvent]
  {
    guard let wait = state.wait,
      wait.isComplete(now: now, monotonic: monotonic, tolerance: tolerance)
    else {
      return []
    }
    state.wait = nil
    state.pendingPass = PendingPass(
      appRefs: wait.appRefs, free: false, waitMinutes: wait.minutes, grantedAt: now,
      origin: wait.origin ?? .shield, blockRef: wait.blockRef)
    var completed = event(.waitCompleted, at: now)
    completed.appRef = wait.primaryApp
    completed.waitMinutes = wait.minutes
    return [completed]
  }

  /// Only the user's Cancel abandons a wait (G-5).
  public func cancelWait(state: inout SharedGateState, now: Date) -> [GateEvent] {
    guard let wait = state.wait else { return [] }
    state.wait = nil
    var abandoned = event(.waitAbandoned, at: now)
    abandoned.appRef = wait.primaryApp
    abandoned.waitMinutes = wait.minutes
    return [abandoned]
  }

  /// "Not now" on a pass that came from a shield: kept for the day, with the picker out of the way.
  public func deferPass(state: inout SharedGateState) {
    state.pendingPass?.deferred = true
  }

  public func resumePass(state: inout SharedGateState) {
    state.pendingPass?.deferred = false
  }

  /// "Not now" on a pass asked for inside Toll: dropped. Nothing was recorded for it.
  public func discardPass(state: inout SharedGateState) {
    state.pendingPass = nil
  }

  /// The session picker's button (G-6). The pass is used here, so this is where it is recorded
  /// (G-7). The session cannot be extended; a new request follows it. A running session that shares
  /// an app with the new one ends here and is returned, so the caller can record `session_ended` and
  /// stop its activity: nothing else would ever see it again.
  public func startSession(
    minutes: Int, state: inout SharedGateState, now: Date, monotonic: MonotonicInstant? = nil
  ) -> (session: ActiveSession, pass: GateEvent, replaced: [ActiveSession])? {
    guard let pending = state.pendingPass else { return nil }
    state.pendingPass = nil
    let session = ActiveSession(
      appRefs: pending.appRefs, minutes: minutes, startedAt: now, blockRef: pending.blockRef,
      startedMonotonic: monotonic)
    let replaced = state.sessions.filter { !Set($0.appRefs).isDisjoint(with: session.appRefs) }
    state.sessions.removeAll { replaced.contains($0) }
    state.sessions.append(session)
    state.lastSessionMinutes = minutes
    var pass = event(.pass, at: now)
    pass.appRef = pending.appRefs.first
    pass.appRefs = pending.appRefs
    pass.blockRef = pending.blockRef
    pass.free = pending.free
    pass.waitMinutes = pending.waitMinutes
    return (session, pass, replaced)
  }

  /// "Block again": the user ends a session before its time is up.
  public func endSession(_ id: UUID, state: inout SharedGateState) -> ActiveSession? {
    guard let index = state.sessions.firstIndex(where: { $0.id == id }) else { return nil }
    return state.sessions.remove(at: index)
  }

  public func sessionEnded(_ session: ActiveSession, at date: Date) -> GateEvent {
    var ended = event(.sessionEnded, at: date)
    ended.appRef = session.appRefs.first
    ended.appRefs = session.appRefs
    ended.sessionMinutes = session.minutes
    return ended
  }

  /// A pass left unused at the day's end lapses so it cannot be spent tomorrow.
  public func expireStalePass(state: inout SharedGateState, now: Date) {
    guard let pending = state.pendingPass else { return }
    let math = DayMath(timeZone: timeZone, resetHour: config.dayResetHour)
    if math.day(containing: pending.grantedAt) != math.day(containing: now) {
      state.pendingPass = nil
    }
  }

  /// Keeps the shield subtitle's count current (spec §10 "You've unblocked this 2 times today.").
  public func refreshUnblocks(state: inout SharedGateState, ledger: GateLedger, now: Date) {
    let math = DayMath(timeZone: timeZone, resetHour: config.dayResetHour)
    state.unblocksDay = math.day(containing: now)
    state.unblocks = ledger.passesByApp
    state.resetHour = config.dayResetHour
  }
}
