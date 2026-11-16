import Foundation
import TollCore
import TollData

/// What Home's state bar and its sheet need from the model (design §3.18).
extension HomeModel {
  enum OffSince: Equatable {
    case today, yesterday
    case weekday(String)
  }

  var barState: HomeBarState {
    HomeBarState.resolve(
      device: deviceState, gate: app.gate, states: blockStates, now: app.deps.clock.now)
  }

  var canAddBlock: Bool {
    BlockLimits.canAddBlock(existing: blockStates.count, config: app.config.blocks)
  }

  /// Every app in every block, once each: what the "Screen time" fact counts.
  var blockedApps: [AppRef] {
    HomeBarState.apps(of: blockStates)
  }

  var dayMath: DayMath {
    DayMath(timeZone: app.deps.clock.timeZone, resetHour: app.config.gate.dayResetHour)
  }

  /// Toll's day, 4 am to 4 am (spec §14), for the report's filter. Its end is the day's, not now, so
  /// the filter is the same value all day and the report is not asked again on every redraw.
  var today: DateInterval {
    let math = dayMath
    let day = math.day(containing: app.deps.clock.now)
    return DateInterval(start: math.start(of: day), end: math.end(of: day))
  }

  func clockTime(of date: Date) -> ClockTime {
    dayMath.clockTime(of: date)
  }

  /// "Since Tuesday" (design §3.18): today, yesterday, or the weekday it went off.
  var screenTimeOffSince: OffSince? {
    guard let at = screenTimeOffAt else { return nil }
    let math = dayMath
    let then = math.day(containing: at)
    let now = math.day(containing: app.deps.clock.now)
    switch then.days(until: now) {
    case ...0: return .today
    case 1: return .yesterday
    default: return .weekday(Copy.weekdayName(then))
    }
  }

  /// Remembered across launches, so "Since" keeps the day it first went off.
  func noteScreenTimeOff(_ isOff: Bool) async {
    let key = "screenTimeOffAt"
    let store = app.deps.store
    if !isOff {
      if screenTimeOffAt != nil {
        setScreenTimeOffAt(nil)
        try? await store.setSetting(key, nil as Date?)
      }
      return
    }
    if screenTimeOffAt != nil { return }
    if let saved = try? await store.setting(key, as: Date.self) {
      setScreenTimeOffAt(saved)
      return
    }
    let now = app.deps.clock.now
    setScreenTimeOffAt(now)
    try? await store.setSetting(key, now)
  }
}
