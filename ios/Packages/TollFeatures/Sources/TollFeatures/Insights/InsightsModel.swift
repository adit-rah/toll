import Foundation
import Observation
import TollCore
import TollData

/// Insights (E8.37, E8.39, insights spec §3). Me comes from the device; Friends and School from the
/// server's rollups. Small numbers are suppressed, never shown as noise (§7).
@MainActor
@Observable
public final class InsightsModel {
  public enum Segment: Hashable, CaseIterable, Sendable { case me, friends, school }
  public enum RemoteState: Equatable, Sendable { case idle, loading, loaded, failed }

  let app: AppModel
  public var segment: Segment = .me
  public var hourRangeIsEightWeeks = false
  public private(set) var me = MeData()
  // Apart from `me` so marking a week redraws one card, not all of them.
  public private(set) var examWeeks: Set<TollDay> = []
  public private(set) var friends: FriendsInsights?
  public private(set) var school: SchoolInsights?
  public private(set) var friendsState: RemoteState = .idle
  public private(set) var schoolState: RemoteState = .idle
  public var selectedDay: TollDay?
  public var shareShown = false
  private var remoteWeek: TollDay?
  private var remoteLoadedAt: Date?

  public init(app: AppModel) {
    self.app = app
  }

  var math: DayMath { DayMath(timeZone: app.deps.clock.timeZone, resetHour: app.config.gate.dayResetHour) }
  var engine: MetricsEngine { MetricsEngine(math: math, config: app.config) }
  public var thisWeekStart: TollDay { math.week(containing: app.deps.clock.now) }
  public var minN: Int { app.config.insights.minN }
  public var lateStartLabel: String { Copy.Schedules.time(ClockTime(hour: app.config.insights.lateStart)) }
  public var hourRange: Metrics { hourRangeIsEightWeeks ? me.eightWeeks : me.thisWeek }

  /// Runs each time the tab appears: the device's numbers always, the server's only when stale.
  public func load() async {
    await loadMe()
    await loadRemote(force: false)
  }

  public func refresh() async {
    await loadMe()
    await loadRemote(force: true)
  }

  public func loadMe() async {
    let store = app.deps.store
    let events = (try? await store.allEvents()) ?? []
    let apps = (try? await store.apps()) ?? []
    let marked = (try? await store.examWeeks()) ?? []
    let week = thisWeekStart
    let opensThis = await opens(from: week, days: 7)
    let opensLast = await opens(from: week.adding(days: -7), days: 7)
    let input = MeInput(
      events: events,
      tags: Dictionary(
        apps.compactMap { stored in stored.tag.map { (stored.appRef, $0) } }, uniquingKeysWith: { first, _ in first }),
      opensThis: opensThis, opensLast: opensLast, now: app.deps.clock.now, engine: engine)
    // Every card's numbers come from walking the whole event log several times; on the main actor
    // that stalls the tab switch that started it.
    let data = await Task.detached(priority: .userInitiated) { MeData.compute(input) }.value
    // Charts redraw when `me` is assigned, so an unchanged result must not assign.
    if data != me { me = data }
    if marked != examWeeks { examWeeks = marked }
    if let day = selectedDay, !data.days.contains(where: { $0.day == day }) { selectedDay = nil }
  }

  private func opens(from start: TollDay, days: Int) async -> Int {
    var total = 0
    for offset in 0..<days { total += (try? await app.deps.store.tollOpens(day: start.adding(days: offset))) ?? 0 }
    return total
  }

  private func loadRemote(force: Bool) async {
    guard app.isSignedIn else {
      // Solo mode has nothing to fetch; anything held is from an account that has signed out.
      if remoteLoadedAt != nil {
        friends = nil
        school = nil
        friendsState = .idle
        schoolState = .idle
        remoteLoadedAt = nil
      }
      return
    }
    let week = thisWeekStart
    let now = app.deps.clock.now
    // Rollups move no faster than this phone uploads, so the sync interval is also how long a
    // fetched answer stays good; inside it a tab switch costs no request.
    let lifetime = TimeInterval(app.config.sync.flushIntervalSeconds)
    let fresh = remoteLoadedAt.map { now.timeIntervalSince($0) < lifetime } ?? false
    if !force, fresh, remoteWeek == week { return }
    if friends == nil { friendsState = .loading }
    if school == nil { schoolState = .loading }
    async let f = try? app.deps.network.friendsInsights(week: week)
    async let s = try? app.deps.network.schoolInsights(week: week)
    let (newFriends, newSchool) = await (f, s)
    // Assigning an equal value still redraws every chart that reads it.
    if let newFriends, newFriends != friends { friends = newFriends }
    if let newSchool, newSchool != school { school = newSchool }
    let friendsNow: RemoteState = friends == nil ? .failed : .loaded
    let schoolNow: RemoteState = school == nil ? .failed : .loaded
    if friendsState != friendsNow { friendsState = friendsNow }
    if schoolState != schoolNow { schoolState = schoolNow }
    if newFriends != nil || newSchool != nil {
      remoteWeek = week
      remoteLoadedAt = now
    }
  }

  /// I-9: marking is local first and synced as a flag per user-week (E8.40).
  public func toggleExamWeek(_ week: TollDay) async {
    let marked = !examWeeks.contains(week)
    if marked { examWeeks.insert(week) } else { examWeeks.remove(week) }
    try? await app.deps.store.setExamWeek(week, marked: marked)
    await app.deps.sync.enqueue(marked ? "PUT" : "DELETE", "exam-weeks/\(week)", json: Empty?.none)
    await app.deps.sync.flush()
  }

  // MARK: Captions (insights spec §5): facts with numbers, omitted under the small-n rule.

  public var lateCaption: String? {
    let m = hourRange
    guard m.passes >= minN, let share = m.lateShare else { return nil }
    return Copy.Insights.lateShare(Int((share * 100).rounded()), after: lateStartLabel)
  }

  public var gatesCaption: String? {
    guard me.thisWeek.hits >= minN, let held = me.thisWeek.heldPercent else { return nil }
    return Copy.Insights.walkedAway(held)
  }

  public var examCaption: String? {
    let marked = me.weeks.filter { examWeeks.contains($0.start) }
    let other = me.weeks.filter { !examWeeks.contains($0.start) }
    guard !marked.isEmpty, !other.isEmpty else { return nil }
    let average = { (rows: [MeData.Week]) in
      Int((Double(rows.reduce(0) { $0 + $1.passes }) / Double(rows.count)).rounded())
    }
    return Copy.Insights.examComparison(exam: average(marked), other: average(other))
  }
}

/// What the device knows about its own person, for every Me card and the share cards.
public struct MeData: Equatable, Sendable {
  public struct Week: Equatable, Sendable, Identifiable {
    public var start: TollDay
    public var label: String
    public var passes: Int
    public var heldPercent: Int?
    public var id: TollDay { start }
  }

  public var thisWeek = Metrics()
  public var lastWeek = Metrics()
  public var eightWeeks = Metrics()
  public var tollOpensThis = 0
  public var tollOpensLast = 0
  public var today: TollDay?
  public var days: [DayMetrics] = []
  public var weekdayAverages: [Weekday: Double] = [:]
  public var weeks: [Week] = []
  public var term: [DayMetrics] = []
  public var tags: [AppRef: Tag] = [:]
  public var weekRange = ""

  public init() {}
}

struct MeInput: Sendable {
  var events: [GateEvent]
  var tags: [AppRef: Tag]
  var opensThis: Int
  var opensLast: Int
  var now: Date
  var engine: MetricsEngine
}

extension MeData {
  static func compute(_ input: MeInput) -> MeData {
    let engine = input.engine
    let math = engine.math
    let today = math.day(containing: input.now)
    let week = today.weekStart
    let weekEnd = week.adding(days: 6)
    let starts = (0..<8).map { week.adding(days: -7 * (7 - $0)) }
    let first = starts.first ?? week
    // Held looks forward from a hit, never back, so nothing before the eight weeks can change them.
    let cutoff = math.start(of: first)
    let recent = input.events.filter { $0.occurredAt >= cutoff }
    let perWeek = starts.map { engine.metrics(recent, from: $0, through: $0.adding(days: 6), tags: input.tags) }

    var data = MeData()
    data.today = today
    data.tags = input.tags
    data.tollOpensThis = input.opensThis
    data.tollOpensLast = input.opensLast
    data.thisWeek = perWeek.last ?? Metrics()
    data.lastWeek = perWeek.count >= 2 ? perWeek[perWeek.count - 2] : Metrics()
    data.eightWeeks = engine.metrics(recent, from: first, through: weekEnd)
    data.weekdayAverages = engine.weekdayAverages(recent, weeks: starts)
    data.weeks = zip(starts, perWeek).map { start, metrics in
      Week(
        start: start, label: math.start(of: start).formatted(.dateTime.month(.abbreviated).day()),
        passes: metrics.passes, heldPercent: metrics.heldPercent)
    }
    data.days = engine.days(recent, from: week.adding(days: -7), through: weekEnd)
    if let earliest = input.events.map(\.occurredAt).min() {
      data.term = engine.days(input.events, from: math.day(containing: earliest).weekStart, through: weekEnd)
    }
    data.weekRange = (math.start(of: week)..<math.start(of: weekEnd)).formatted(.interval.month(.abbreviated).day())
    return data
  }
}
