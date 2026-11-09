import Foundation
import Observation
import TollCore
import TollData

/// Insights (E8.37, E8.39, insights spec §3). Me comes from the device; Friends and School from the
/// server's rollups. Small numbers are suppressed, never shown as noise (§7).
@MainActor
@Observable
public final class InsightsModel {
  public enum Segment: Hashable, CaseIterable { case me, friends, school }

  public struct MeData: Equatable {
    public var thisWeek = Metrics()
    public var lastWeek = Metrics()
    public var tollOpensThis = 0
    public var tollOpensLast = 0
    public var days: [DayMetrics] = []
    public var hourRange = Metrics()
    public var weekdayAverages: [Weekday: Double] = [:]
    public var weeks: [(week: TollDay, passes: Int, heldPercent: Int?)] = []
    public var term: [DayMetrics] = []
    public var examWeeks: Set<TollDay> = []

    public static func == (lhs: MeData, rhs: MeData) -> Bool {
      lhs.thisWeek == rhs.thisWeek && lhs.days == rhs.days && lhs.examWeeks == rhs.examWeeks
        && lhs.weeks.map(\.passes) == rhs.weeks.map(\.passes)
    }
  }

  let app: AppModel
  public var segment: Segment = .me
  public var hourRangeIsEightWeeks = false { didSet { Task { await loadMe() } } }
  public private(set) var me = MeData()
  public private(set) var tags: [AppRef: Tag] = [:]
  public private(set) var friends: FriendsInsights?
  public private(set) var school: SchoolInsights?
  public var selectedDay: DayMetrics?
  public var shareShown = false

  public init(app: AppModel) {
    self.app = app
  }

  var math: DayMath { DayMath(timeZone: app.deps.clock.timeZone, resetHour: app.config.gate.dayResetHour) }
  var engine: MetricsEngine { MetricsEngine(math: math, config: app.config) }
  public var thisWeekStart: TollDay { math.week(containing: app.deps.clock.now) }
  public var minN: Int { app.config.insights.minN }
  public var lateStartLabel: String { Copy.Schedules.time(ClockTime(hour: app.config.insights.lateStart)) }

  public func load() async {
    await loadMe()
    guard app.isSignedIn else { return }
    async let f = try? app.deps.network.friendsInsights(week: thisWeekStart)
    async let s = try? app.deps.network.schoolInsights(week: thisWeekStart)
    friends = await f
    school = await s
  }

  public func loadMe() async {
    let events = (try? await app.deps.store.allEvents()) ?? []
    let apps = (try? await app.deps.store.apps()) ?? []
    tags = Dictionary(uniqueKeysWithValues: apps.compactMap { a in a.tag.map { (a.appRef, $0) } })
    let week = thisWeekStart
    var data = MeData()
    data.thisWeek = engine.metrics(events, from: week, through: week.adding(days: 6), tags: tags)
    data.lastWeek = engine.metrics(events, from: week.adding(days: -7), through: week.adding(days: -1), tags: tags)
    data.tollOpensThis = await opens(from: week, days: 7)
    data.tollOpensLast = await opens(from: week.adding(days: -7), days: 7)
    data.days = engine.days(events, from: week.adding(days: -7), through: week.adding(days: 6))
    let hourStart = hourRangeIsEightWeeks ? week.adding(days: -49) : week
    data.hourRange = engine.metrics(events, from: hourStart, through: week.adding(days: 6))
    let eight = (0..<8).map { week.adding(days: -7 * (7 - $0)) }
    data.weekdayAverages = engine.weekdayAverages(events, weeks: eight)
    data.weeks = eight.map { start in
      let m = engine.metrics(events, from: start, through: start.adding(days: 6))
      return (start, m.passes, m.heldPercent)
    }
    let termStart = events.first.map { math.day(containing: $0.occurredAt) } ?? week
    data.term = engine.days(events, from: termStart.weekStart, through: week.adding(days: 6))
    data.examWeeks = (try? await app.deps.store.examWeeks()) ?? []
    me = data
  }

  private func opens(from start: TollDay, days: Int) async -> Int {
    var total = 0
    for offset in 0..<days { total += (try? await app.deps.store.tollOpens(day: start.adding(days: offset))) ?? 0 }
    return total
  }

  /// I-9: marking is local first and synced as a flag per user-week (E8.40).
  public func toggleExamWeek(_ week: TollDay) async {
    let marked = !me.examWeeks.contains(week)
    try? await app.deps.store.setExamWeek(week, marked: marked)
    await app.deps.sync.enqueue(marked ? "PUT" : "DELETE", "exam-weeks/\(week)", json: Empty?.none)
    await app.deps.sync.flush()
    await loadMe()
  }

  // MARK: Captions (insights spec §5): facts with numbers, omitted under the small-n rule.

  public var lateCaption: String? {
    let m = me.hourRange
    guard m.passes >= minN, let share = m.lateShare else { return nil }
    return Copy.Insights.lateShare(Int((share * 100).rounded()), after: lateStartLabel)
  }

  public var gatesCaption: String? {
    guard me.thisWeek.hits >= minN, let held = me.thisWeek.heldPercent else { return nil }
    return Copy.Insights.walkedAway(held)
  }

  public var examCaption: String? {
    let marked = me.weeks.filter { me.examWeeks.contains($0.week) }
    let other = me.weeks.filter { !me.examWeeks.contains($0.week) }
    guard !marked.isEmpty, !other.isEmpty, marked.count + other.count >= 2 else { return nil }
    let avg = { (rows: [(week: TollDay, passes: Int, heldPercent: Int?)]) in
      Int((Double(rows.reduce(0) { $0 + $1.passes }) / Double(rows.count)).rounded())
    }
    return Copy.Insights.examComparison(exam: avg(marked), other: avg(other))
  }
}
