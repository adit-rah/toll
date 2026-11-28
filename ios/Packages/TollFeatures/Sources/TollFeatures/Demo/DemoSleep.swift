#if DEBUG
  import Foundation
  import TollCore

  /// Your sleep's measures (#87, #88) and last night's card with Health's sleep (#86): four weeks
  /// of a watch's nights getting earlier, staying flat, or too noisy to say; the same weeks from
  /// Dusk's own nights alone; three nights; and the first morning's ask.
  extension DemoScenario {
    enum SleepStory {
      case improving, flat, noisy, dusk, few
    }

    var sleepStory: SleepStory? {
      switch self {
      case .sleepHealthImproving, .homeMorningAsleep, .homeMorningAsleepOpen: .improving
      case .sleepHealthFlat: .flat
      case .sleepHealthNoisy: .noisy
      case .sleepDusk: .dusk
      case .sleepFew: .few
      default: nil
      }
    }

    /// Nights since setup, all of them in the night log.
    var sleepNights: Int? { sleepStory.map { $0 == .few ? 3 : 28 } }
  }

  extension DemoFixture {
    /// The night log for a sleep story, oldest first: each night the lock ran, with Health's sleep
    /// unless the story has none, and Dusk's reaches and pauses.
    mutating func addSleep(_ scenario: DemoScenario, now: Date) {
      guard let story = scenario.sleepStory, let nights = scenario.sleepNights else { return }
      state.health = story != .dusk
      history = (1...nights).reversed().compactMap { Self.night($0, of: nights, story, now: now) }
    }

    /// A fixed wobble, so renders are the same every time.
    static let wobble: [Double] = [
      -1, 0.6, -0.3, 1, -0.7, 0.2, 0.5, -0.5, 0.9, -0.2, 0.1, -0.9, 0.4, 0,
    ]

    static func night(_ back: Int, of total: Int, _ story: DemoScenario.SleepStory, now: Date)
      -> PastNight?
    {
      let calendar = Calendar.current
      guard let day = calendar.date(byAdding: .day, value: -back, to: now),
        let lock = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day),
        let eleven = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: day)
      else { return nil }
      // 0 at the first night, 1 at last night.
      let progress = Double(total - back) / Double(max(1, total - 1))
      let w = wobble[back % wobble.count]
      let onset: Double
      let asleep: Double
      let reaches: Int
      switch story {
      case .improving, .dusk:
        // Earlier over the first two weeks, then held, so the weekly line (#165) says it whatever
        // day the demo runs.
        let step = min(1, 2 * progress)
        onset = 50 - 40 * step + w * (20 - 12 * progress)
        asleep = 410 + 40 * step + w * 12
        reaches = max(0, Int((4 - 3 * step + w).rounded()))
      case .flat, .few:
        onset = 20 + w * 12
        asleep = 440 + w * 20
        reaches = max(0, Int((2 + w).rounded()))
      case .noisy:
        onset = 25 - 15 * progress + w * 60
        asleep = 430 + w * 70
        reaches = max(0, Int((2 + 2 * w).rounded()))
      }
      // Last night, as the card shows it: asleep 11:20 pm – 6:55 am.
      let minutes = back == 1 && story == .improving ? 20 : onset
      let length = back == 1 && story == .improving ? 455 : asleep
      let start = eleven.addingTimeInterval(minutes * 60)
      let slept =
        story == .dusk
        ? nil
        : PastNight.Slept(
          onset: start, wake: start.addingTimeInterval(length * 60), minutes: Int(length))
      // The last reach for a locked app comes a little before sleep.
      let reach = reaches > 0 ? eleven.addingTimeInterval((onset - 12) * 60) : nil
      return PastNight(
        night: calendar.startOfDay(for: day), ran: true, start: lock,
        end: lock.addingTimeInterval(9.25 * 3600), locked: 9.25 * 3600, taps: [], slept: slept,
        lastReach: reach, reaches: reaches, pauses: back % 9 == 4 ? 1 : 0)
    }
  }
#endif
