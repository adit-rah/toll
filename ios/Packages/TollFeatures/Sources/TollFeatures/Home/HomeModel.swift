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

  public init(app: AppModel) {
    self.app = app
  }

  public var personalised: Bool {
    app.config.status.personalise && you.level != nil
  }

  public func start() async {
    home = await app.deps.network.cachedHome()
    await updateDeviceState()
    observe()
    if app.isSignedIn { await refresh() }
  }

  public func markAppeared() { hasAppeared = true }

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
    let days = engine.days(events, from: week, through: week.adding(days: 6))
    var you = You()
    you.passesToday = days.first { $0.day == today }?.passes ?? 0
    you.strip = days.map(\.passes)
    you.todayIndex = week.days(until: today)
    you.thisWeek = days.reduce(0) { $0 + $1.passes }
    you.lastWeek = engine.metrics(events, from: week.adding(days: -7), through: week.adding(days: -1)).passes
    let history = engine.dailyHistory(events, before: today, days: StatusRules.personalisedHistoryDays)
    you.level = StatusRules.level(passesToday: you.passesToday, history: history, config: app.config.status)
    self.you = you
    activeSession = app.gate.sessions.first { !$0.isExpired(at: now) }
  }

  public func refresh() async {
    guard app.isSignedIn else { return }
    isRefreshing = true
    defer { isRefreshing = false }
    await app.deps.sync.flush(force: true)
    if let fresh = try? await app.deps.network.refreshHome() { home = fresh }
  }

  public func updateDeviceState() async {
    let blocks = (try? await app.deps.store.blocks()) ?? []
    if ScreenTimeAuthorization.state != .approved {
      deviceState = .screenTimeOff
    } else if blocks.isEmpty {
      deviceState = .nothingBlocked
    } else if TokenRegistry().tokens(for: blocks.flatMap(\.appRefs)).isEmpty {
      deviceState = .blocksNeedRepicking
    } else {
      deviceState = nil
    }
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
    let date = Date(millis: asOf)
    return app.deps.clock.now.timeIntervalSince(date) > 3600 ? date : nil
  }
}
