#if DEBUG
  import Foundation
  import TollCore

  /// Onboarding fitted to sleep and its one-time flow, in demo launches (#144): what Health would
  /// have answered, and which step each scenario opens on.
  extension DemoScenario {
    /// The one-time flow's sheet, on its step.
    var fitSheetPath: [FitFlowSheet.Step]? {
      switch self {
      case .fitSheet: []
      case .fitSheetSleep: [.sleep]
      case .fitSheetAround: [.sleep, .around]
      default: nil
      }
    }

    /// The side whose sheet the screen opens on.
    var bufferSheet: Gap.Side? {
      switch self {
      case .aroundBefore: .before
      case .settingsSleepAfter: .after
      default: nil
      }
    }

    /// Someone set up before #144: no buffer after yet, and the flow due.
    var fitOffered: Bool { self == .homeFitCard || fitSheetPath != nil }

    /// Health's answer, as the onboarding step after "Use Apple Health" holds it.
    @MainActor func prepare(_ draft: FitDraft, now: Date = Date()) {
      switch self {
      case .sleepFound:
        draft.health = true
        draft.found(DemoHealth.estimate(now: now))
      case .sleepFoundWeekends:
        draft.health = true
        draft.found(DemoHealth.estimate(weekends: true, now: now))
      case .readyHealth:
        draft.health = true
        draft.found(DemoHealth.estimate(weekends: true, now: now))
      case .sleepNone:
        draft.health = true
        draft.found(nil)
      case .aroundOff:
        draft.found(nil)
        draft.setStart(.after, 0)
      default:
        draft.found(nil)
      }
    }
  }

  /// Four weeks of a watch's nights: asleep about 11:20 pm and up about 7:10 am; on Fri and Sat
  /// nights, with `weekends`, about 12:30 am to 9 am.
  enum DemoHealth {
    static func estimate(weekends: Bool = false, now: Date) -> SleepEstimate? {
      let calendar = Calendar.current
      var samples: [SleepSample] = []
      for back in 1...27 {
        guard let day = calendar.date(byAdding: .day, value: -back, to: now) else { continue }
        let late = weekends && Weekday.weekendNights.contains(Weekday(of: day, calendar: calendar))
        // A few minutes either way each night, as a real week reads.
        let wobble = TimeInterval((back * 7 % 11 - 5) * 60)
        guard
          let onset = calendar.date(
            bySettingHour: late ? 0 : 23, minute: late ? 30 : 20, second: 0,
            of: late ? calendar.date(byAdding: .day, value: 1, to: day) ?? day : day)
        else { continue }
        let start = onset.addingTimeInterval(wobble)
        let end = start.addingTimeInterval(late ? 8.5 * 3600 : 7 * 3600 + 50 * 60)
        samples.append(
          SleepSample(start: start, end: end, kind: .asleep, source: .watch, sourceID: "watch"))
      }
      return SleepEstimate(
        SleepNight.from(samples, calendar: calendar), now: now, calendar: calendar)
    }
  }
#endif
