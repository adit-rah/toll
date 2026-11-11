import Foundation
import Observation
import TollCore
import TollData
import TollScreenTime

/// Home (E5.30, design §4.1): you from the local event log, friends from the cached `/home`, the device
/// state line, the session line, and the Toll-opens footer.
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
  public private(set) var activeSession: ActiveSession?
  public private(set) var isRefreshing = false
  public private(set) var hasAppeared = false
  private var observation: Task<Void, Never>?
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
    showActiveSession(at: now)
  }

  private func showActiveSession(at now: Date) {
    let session = app.gate.sessions.first { !$0.isExpired(at: now) }
    if activeSession != session { activeSession = session }
  }

  public func refresh() async {
    guard app.isSignedIn else { return }
    isRefreshing = true
    defer { isRefreshing = false }
    await app.deps.sync.flush(force: true)
    if let fresh = try? await app.deps.network.refreshHome() { show(fresh) }
  }

  /// Home calls this whenever the gate's state changes.
  public func updateDeviceState() async {
    // A session starts and ends in the gate's state without writing an event, so the session line
    // cannot wait for the event log to speak.
    showActiveSession(at: app.deps.clock.now)
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
