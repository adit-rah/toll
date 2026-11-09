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
    if var pending = state.pendingPass {
      if !pending.appRefs.contains(appRef) { pending.appRefs.append(appRef) }
      state.pendingPass = pending
      return []
    }
    switch GateRules.entry(ledger: ledger, runningWait: state.wait, config: config) {
    case .joinWait:
      state.wait?.join(appRef)
      return []
    case .freePass:
      state.pendingPass = PendingPass(appRefs: [appRef], free: true, waitMinutes: 0, grantedAt: now)
      var pass = event(.pass, at: now)
      pass.appRef = appRef
      pass.appRefs = [appRef]
      pass.free = true
      pass.waitMinutes = 0
      return [pass]
    case .startWait(let minutes, let number):
      state.wait = Wait(
        appRef: appRef, number: number, minutes: minutes, startedAt: now,
        startedMonotonic: monotonic)
      var started = event(.waitStarted, at: now)
      started.appRef = appRef
      started.waitMinutes = minutes
      return [started]
    }
  }

  /// Turns a finished wait into a waited pass. Called whenever Toll is in front (G-4: the user comes back
  /// when they come back; nothing notifies them).
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
      appRefs: wait.appRefs, free: false, waitMinutes: wait.minutes, grantedAt: now)
    var completed = event(.waitCompleted, at: now)
    completed.appRef = wait.primaryApp
    completed.waitMinutes = wait.minutes
    var pass = event(.pass, at: now)
    pass.appRef = wait.primaryApp
    pass.appRefs = wait.appRefs
    pass.free = false
    pass.waitMinutes = wait.minutes
    return [completed, pass]
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

  /// The session picker's Open (G-6). The session cannot be extended; a new request follows it.
  public func startSession(minutes: Int, state: inout SharedGateState, now: Date) -> ActiveSession?
  {
    guard let pending = state.pendingPass else { return nil }
    state.pendingPass = nil
    let session = ActiveSession(
      appRefs: pending.appRefs, minutes: minutes, startedAt: now,
      windowMinutes: config.sessionWindowMinutes)
    state.sessions.removeAll { !Set($0.appRefs).isDisjoint(with: session.appRefs) }
    state.sessions.append(session)
    state.lastSessionMinutes = minutes
    return session
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
