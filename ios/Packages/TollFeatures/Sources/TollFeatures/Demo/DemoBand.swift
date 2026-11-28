#if DEBUG
  import Foundation
  import TollCore

  /// Tonight's band's scenarios (`TonightBand`, docs/renders.md): each pair it allows, and the hour
  /// before the lock.
  extension DemoScenario {
    /// Mornings with last night's row under a card: a problem, Monday's card on Tuesday, a
    /// one-time flow, and the home card with last night open.
    static let bandMornings: [DemoScenario] = [
      .homeMorningLocation, .homeMorningCardOpen, .homeMorningGapWeek, .homeMorningFlow,
    ]

    /// 9:30 pm, inside the hour before the lock: the heads-up offer is due and waits.
    var nightHour: Bool { [.homeNightHour, .homeNightHourMonday].contains(self) }

    /// The gap grew from 15 to 30 this week (D76): Monday's evening, its hour before the lock, and
    /// Tuesday's morning, when the card still shows with last night's row.
    var mondaysCard: Bool {
      [.homeGapWeek, .homeNightHourMonday, .homeMorningGapWeek].contains(self)
    }

    /// The day of the week the scenario falls on, the latest such day: 1 is Sunday, 2 Monday.
    var weekday: Int? {
      switch self {
      case .sleepBest: 1
      case .sleepMonday, .homeGapWeek, .homeNightHourMonday: 2
      case .homeMorningGapWeek: 3
      default: nil
      }
    }

    /// The heads-up offer answered with "Turn on" a moment ago (#160).
    var headsUpAnswered: Bool { [.homeHeadsUpOn, .homeHeadsUpDenied].contains(self) }

    /// The one-time flow the band shows (D92): #1, "Fit Dusk to your sleep" (#144).
    var flow: String? { fitOffered ? Flows.fitSleep.id : nil }
  }
#endif
