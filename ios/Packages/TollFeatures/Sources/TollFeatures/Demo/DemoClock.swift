#if DEBUG
  import Foundation
  import TollCore

  /// The demo's "now", pinned so every render reads as a night whatever the machine's clock says
  /// (#73): 11:40 pm inside Sleep's 10:30 pm – 7:00 am for states during the night, 7:55 pm before it,
  /// 8:10 am for the morning card (#103), 11 am on a weekday with Study on (#89), on a Monday or a
  /// Sunday where the week matters.
  enum DemoClock {
    static func now(for scenario: DemoScenario, today: Date = Date()) -> Date {
      let calendar = Calendar.current
      let night =
        scenario == .homeBlocked || scenario == .homeScreenTimeOff || scenario == .homeAway
        || scenario.isDoor || scenario == .homePauseOpen || scenario == .sleepSkyNight
      // In the gap before bed: the lock came on at 10 pm, half an hour before bed (D80).
      if scenario.inGap {
        return calendar.date(bySettingHour: 22, minute: 15, second: 0, of: today) ?? today
      }
      // 1 is Sunday, 2 Monday: the latest such day, today included. Day scenarios need Study's
      // hours: the latest weekday.
      let weekday = calendar.component(.weekday, from: today)
      let back: Int
      if scenario == .sleepMonday || scenario == .sleepBest || scenario == .homeGapWeek {
        back = (weekday - (scenario == .sleepBest ? 1 : 2) + 7) % 7
      } else {
        back = scenario.isDay ? [1: 2, 7: 1][weekday] ?? 0 : 0
      }
      let day = calendar.date(byAdding: .day, value: -back, to: today) ?? today
      let (hour, minute) =
        scenario.isMorning ? (8, 10) : night ? (23, 40) : scenario.isDay ? (11, 0) : (19, 55)
      return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
  }

  extension DemoClock {
    /// The 30th night's poster, with last night's moon and date as the phone would make it.
    static func poster(now: Date = Date()) -> Sky.Landmark? {
      let calendar = Calendar.current
      var landmark = Sky(
        nights: 30, newestIsNew: true,
        moon: .lastNight(before: now, calendar: calendar, southern: false)
      ).landmark
      landmark?.date = Copy.Sky.date(
        calendar.date(byAdding: .day, value: -1, to: now) ?? now, calendar: calendar)
      return landmark
    }
  }
#endif
