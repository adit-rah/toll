import Foundation
import Observation
import TollCore
import TollData
import TollScreenTime

/// Home (E5.30, design §4.1): you from the local event log, friends from the cached `/home`, the device
/// state line, and what each block is doing for the block bar.
@MainActor
@Observable
public final class HomeModel {
  public enum DeviceState: Equatable {
    case screenTimeOff, blocksNeedRepicking, nothingBlocked
  }

  public struct You: Equatable {
    public var passesToday = 0
    public var level: StatusLevel?
    public var thisWeek = 0
    public var lastWeek = 0
    public var strip = [Int](repeating: 0, count: 7)
    public var todayIndex = 0
  }

  let app: AppModel
  public private(set) var you = You()
  public private(set) var home: HomeResponse?
  public private(set) var deviceState: DeviceState?
  /// One per stored block, in the block list's order (design §3.18).
  private(set) var blockStates: [BlockState] = []
  public private(set) var isRefreshing = false
  public private(set) var hasAppeared = false
  private var observation: Task<Void, Never>?
  @ObservationIgnored private var blocks: [StoredBlock] = []
  @ObservationIgnored private var blocksObservation: Task<Void, Never>?
  @ObservationIgnored private var blockClock: Task<Void, Never>?
  @ObservationIgnored private var blockClockTarget: Date?
  /// When the server last answered. Apart from `home` so an answer with the same rows can move it
  /// without redrawing them.
  @ObservationIgnored private var syncedAt: Millis?

  public init(app: AppModel) {
    self.app = app
  }

  public var personalised: Bool {
    app.config.status.personalise && you.level != nil
  }

  public func start() async {
    show(await app.deps.network.cachedHome())
    await updateDeviceState()
    observe()
    observeBlocks()
    if app.isSignedIn { await refresh() }
  }

  public func markAppeared() {
    if !hasAppeared { hasAppeared = true }
  }

  /// `asOf` moves with every answer, and Home starts again each time its tab comes back. A response is
  /// published only when a row or the last-synced line would change; otherwise every tab switch redrew
  /// the whole list twice, the second time a network round trip later and often mid-scroll.
  private func show(_ fresh: HomeResponse?) {
    guard let fresh else {
      syncedAt = nil
      if home != nil { home = nil }
      return
    }
    let lineShown = staleSince != nil
    syncedAt = fresh.asOf
    var sameMoment = fresh
    sameMoment.asOf = home?.asOf ?? fresh.asOf
    if lineShown || sameMoment != home { home = fresh }
  }

  private func observe() {
    observation?.cancel()
    let math = DayMath(timeZone: app.deps.clock.timeZone, resetHour: app.config.gate.dayResetHour)
    let since = math.start(of: math.week(containing: app.deps.clock.now).adding(days: -35))
    observation = Task { [weak self] in
      guard let stream = self?.app.deps.store.observeEvents(since: since) else { return }
      do {
        for try await events in stream { self?.compute(events) }
      } catch {}
    }
  }

  private func compute(_ events: [GateEvent]) {
    let math = DayMath(timeZone: app.deps.clock.timeZone, resetHour: app.config.gate.dayResetHour)
    let engine = MetricsEngine(math: math, config: app.config)
    let now = app.deps.clock.now
    let today = math.day(containing: now)
    let week = today.weekStart
    let lastWeek = week.adding(days: -7)
    let historyStart = today.adding(days: -StatusRules.personalisedHistoryDays)
    // One walk over the log for the strip, last week and the status history. This runs on the main actor
    // for every change to the event table; three walks each resolved every event's day again.
    let all = engine.days(events, from: min(lastWeek, historyStart), through: week.adding(days: 6))
    let days = all.filter { $0.day >= week }
    var you = You()
    you.passesToday = days.first { $0.day == today }?.passes ?? 0
    you.strip = days.map(\.passes)
    you.todayIndex = week.days(until: today)
    you.thisWeek = days.reduce(0) { $0 + $1.passes }
    you.lastWeek = all.filter { $0.day >= lastWeek && $0.day < week }.reduce(0) { $0 + $1.passes }
    let history = all.filter { $0.day >= historyStart && $0.day < today && $0.active }.map(\.passes)
    you.level = StatusRules.level(passesToday: you.passesToday, history: history, config: app.config.status)
    if self.you != you { self.you = you }
  }

  /// Blocks are added and removed on screens pushed over Home, which never restart Home's own task;
  /// without this the bar and the "Nothing blocked yet" line would outlive what they describe.
  private func observeBlocks() {
    blocksObservation?.cancel()
    blocksObservation = Task { [weak self] in
      guard let stream = self?.app.deps.store.observeBlocks() else { return }
      do {
        for try await stored in stream { await self?.showBlocks(stored) }
      } catch {}
    }
  }

  private func showBlocks(_ stored: [StoredBlock]) async {
    blocks = stored
    updateBlockStates()
    await updateDeviceState()
  }

  /// Recomputed when the blocks or the gate change, and again at the next moment anything changes
  /// by itself. Published only when different: Observation notifies on every assignment.
  func updateBlockStates() {
    let math = DayMath(timeZone: app.deps.clock.timeZone, resetHour: app.config.gate.dayResetHour)
    let now = app.deps.clock.now
    let states = BlockStates.resolve(blocks: blocks, gate: app.gate, at: now, math: math)
    if blockStates != states { blockStates = states }
    wake(at: BlockStates.nextChange(states, gate: app.gate, after: now, math: math))
  }

  /// A window's edge moves nothing in the gate's state and a session's end reaches it only once
  /// something reconciles, so Home sleeps until the moment and asks.
  private func wake(at moment: Date?) {
    if moment == blockClockTarget, blockClock != nil || moment == nil { return }
    blockClock?.cancel()
    blockClock = nil
    blockClockTarget = moment
    guard let moment else { return }
    let pause = max(0.05, moment.timeIntervalSince(app.deps.clock.now))
    blockClock = Task { [weak self] in
      try? await Task.sleep(for: .seconds(pause))
      guard !Task.isCancelled, let self else { return }
      self.blockClock = nil
      self.app.setGate(await self.app.deps.gate.expireSessions())
      self.updateBlockStates()
    }
  }

  /// "Unblock" on a block's card (G-3). A pass set aside for the block is picked up again; if the
  /// day reset has taken it since, this is an ordinary request.
  func unblock(_ state: BlockState) async {
    if state.passReady {
      let resumed = await app.deps.gate.resumePendingPass()
      if resumed.pendingPass != nil {
        app.setGate(resumed)
        return
      }
    }
    app.setGate(await app.deps.gate.requestUnblock(block: state.id))
  }

  /// "Block again" (G-6): the shield goes back up now; the pass that was used still counts.
  func blockAgain(_ state: BlockState) async {
    for id in state.sessionIDs {
      app.setGate(await app.deps.gate.endSession(id))
    }
    updateBlockStates()
  }

  public func refresh() async {
    guard app.isSignedIn else { return }
    isRefreshing = true
    defer { isRefreshing = false }
    await app.deps.sync.flush(force: true)
    if let fresh = try? await app.deps.network.refreshHome() { show(fresh) }
  }

  /// Home calls this whenever the gate's state changes.
  public func gateChanged() async {
    updateBlockStates()
    await updateDeviceState()
  }

  public func updateDeviceState() async {
    let blocks = (try? await app.deps.store.blocks()) ?? []
    let state: DeviceState?
    if ScreenTimeAuthorization.state != .approved {
      state = .screenTimeOff
    } else if blocks.isEmpty {
      state = .nothingBlocked
    } else {
      let refs = blocks.flatMap(\.appRefs)
      // The registry is a file in the App Group, read under file coordination: kept off the main actor.
      let noTokens = await Task.detached { TokenRegistry().tokens(for: refs).isEmpty }.value
      state = noTokens ? .blocksNeedRepicking : nil
    }
    if deviceState != state { deviceState = state }
  }

  public func fixScreenTime() async {
    let state = await ScreenTimeAuthorization.request()
    app.deps.analytics.send(.screenTimeAuth(granted: state == .approved))
    if state == .approved { await app.deps.blocks.applyBlocks() }
    await updateDeviceState()
  }

  /// "Last-synced timestamp is shown only if older than 1 hour" (design §4.1).
  public var staleSince: Date? {
    guard let asOf = home?.asOf else { return nil }
    let date = Date(millis: syncedAt ?? asOf)
    return app.deps.clock.now.timeIntervalSince(date) > 3600 ? date : nil
  }
}
