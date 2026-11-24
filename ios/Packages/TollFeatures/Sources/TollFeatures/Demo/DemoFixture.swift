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
        || scenario.isDoor || scenario == .homePauseOpen
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

  extension DemoScenario {
    /// Scenarios set the morning after a night: Tonight's morning card and Your sleep's weeks.
    var isMorning: Bool {
      [.homeMorning, .homeMorningGap, .homeMorningAway, .sleepMonday, .sleepBest].contains(self)
        || skyNights != nil
    }

    var isGap: Bool { self == .homeGapWeek || self == .homeGapOffer }

    /// Nights the lock has run in Your sky's scenarios (D79), the last of them last night.
    var skyNights: Int? {
      switch self {
      case .sleepSky5: 5
      case .sleepSky7: 7
      case .sleepSky30, .homeMorningLandmark: 30
      case .sleepSky100: 100
      default: nil
      }
    }
  }

  /// A believable state and week for each demo scenario, on the boards' night (10:30 pm – 7:00 am):
  /// Sleep at Home, Study at a library, five nights of log.
  struct DemoFixture {
    var state = DuskState()
    var log: [Transition] = []
    /// Nights from the night log, older than the transition log keeps (#103).
    var history: [PastNight] = []

    init(scenario: DemoScenario, now: Date) {
      let calendar = Calendar.current
      let home = Place(
        id: PlaceID("home"), name: Copy.Setup.homeName, latitude: 51.5246, longitude: -0.0786,
        radiusMeters: 150)
      let library = Place(
        id: PlaceID("library"), name: "Robarts Library", latitude: 43.6644, longitude: -79.3995,
        radiusMeters: 150)
      let pauseOpen = scenario == .doorOpen || scenario == .homePauseOpen
      let blocked =
        scenario == .homeBlocked || scenario == .homeScreenTimeOff || scenario.isDoor || pauseOpen
      let night = TimeWindow(start: ClockTime(hour: 22, minute: 30), end: ClockTime(hour: 7))
      state.places = scenario.homeNotSet ? [library] : [home, library]
      // "Nothing scheduled" is a night with no hours: the one block Dusk always has (D73).
      state.blocks = [
        Block(
          id: BlockID("sleep"), name: Copy.Setup.nightName, kind: .sleep,
          place: scenario.homeNotSet ? nil : home.id,
          schedule: scenario == .homeNoBlocks ? WeeklySchedule(rules: []) : .everyDay(night),
          apps: nil, appCount: 4),
        Block(
          id: BlockID("study"), name: "Study", kind: .study, place: library.id,
          schedule: WeeklySchedule(rules: [
            .init(
              days: Weekday.weekdays,
              window: TimeWindow(start: ClockTime(hour: 9), end: ClockTime(hour: 17)))
          ]), apps: nil, appCount: 3),
      ]
      // The Blocks tab shows more than one other block, and a weekday strip shows Gym after Study.
      if scenario.tab == .blocks || scenario.isDay {
        var gym = BlockDraft.new(.gym)
        gym.id = BlockID("gym")
        gym.appCount = 2
        state.blocks.append(gym)
      }
      if scenario.isDay, let end = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now) {
        state.presence[library.id] = Presence(isInside: true, at: now)
        state.runtime.active[BlockID("study")] = end
        state.unlocks.week = UnlockSupply.week(
          containing: now, calendar: calendar, config: .defaults)
      }
      state.presence[home.id] = Presence(isInside: scenario != .homeAway, at: now)
      let firstWeek = scenario == .homeFirstWeek || scenario == .homePillPurchase
      let later = scenario == .homeWeek || scenario == .sleepMonday
      let paused = scenario == .homePaused
      let morning = scenario.isMorning
      // Home not set: set up this evening, or the evening before the card's first night ended.
      let nightsAgo =
        scenario == .homeAnywhere || scenario.setHomePath != nil
        ? 0
        : firstWeek || scenario == .homeCard || scenario == .homeHeadsUp
          ? 1
          : scenario == .homeLastNight
            ? 13
            : later
              ? 20
              : paused
                ? 8
                : scenario == .sleepBest
                  ? 6 : scenario.skyNights.map { min($0, 5) } ?? (morning ? 9 : 4)
      // A personal best and a long sky need nights before these, which only the night log holds.
      let setupAgo =
        scenario == .sleepBest ? 27 : scenario.skyNights.map { $0 + 1 } ?? nightsAgo
      state.setupFinishedAt =
        setupAgo == 0
        ? now.addingTimeInterval(-3600)
        : calendar.date(byAdding: .day, value: -setupAgo, to: now)
      state.trial.start = state.setupFinishedAt
      state.trial.purchased = later || morning || scenario.isGap
      // A new install locks 15 minutes before bed (D76); the offer is for one from before it.
      state.gap = scenario == .homeGapOffer ? .existing : .newInstall()
      if scenario == .homeGapWeek {
        state.gap.minutes = 30
        state.gap.change = Gap.Change(
          week: UnlockSupply.week(containing: now, calendar: calendar, config: .defaults),
          from: 15, to: 30)
      }
      if scenario == .homePaused {
        state.trial.start = calendar.date(byAdding: .day, value: -15, to: now)
        state.trial.entitled = false
      }
      if scenario == .homeLocation { state.location = .scheduleOnly }
      if blocked {
        state.runtime.active[BlockID("sleep")] =
          night.night(
            startingOn: calendar.startOfDay(for: now), calendar: calendar)?.end
        state.doorAskedAt = scenario.isDoor ? now : nil
        state.unlocks.spent = scenario == .doorNone ? 3 : 1
        state.unlocks.week = UnlockSupply.week(
          containing: now, calendar: calendar, config: .defaults)
        if scenario == .doorWaiting || pauseOpen {
          // The pause's countdowns run on the real clock, so its times do too; Tonight's hero has
          // no countdown, so it keeps the demo's.
          let real = scenario == .homePauseOpen ? now : Date()
          var door = Door(waitEndsAt: real.addingTimeInterval(scenario == .doorWaiting ? 54 : -48))
          if pauseOpen {
            door.openedAt = real.addingTimeInterval(-48)
            door.expiresAt = door.waitEndsAt.addingTimeInterval(
              TimeInterval(TollConfig.defaults.door.minutes * 60))
          }
          state.door = door
        }
      }
      // Tonight's block counts as tonight's bar once it has come on.
      if blocked {
        log.append(
          Transition(
            at: now.addingTimeInterval(-3600), cause: .windowStart, blockOn: true, changed: true,
            home: true, inWindow: true, entitled: true))
      }
      if scenario == .sleepBest {
        // Weeks of 5, 4 and 5 nights before this one's 6.
        history = (7...27).compactMap { back in
          calendar.date(byAdding: .day, value: -back, to: now).map {
            PastNight(
              night: calendar.startOfDay(for: $0),
              ran: ![9, 12, 15, 17, 18, 22, 25].contains(back))
          }
        }
      }
      if let sky = scenario.skyNights, sky > nightsAgo {
        history = (nightsAgo + 1...sky).compactMap { back in
          calendar.date(byAdding: .day, value: -back, to: now).map {
            PastNight(night: calendar.startOfDay(for: $0), ran: true)
          }
        }
      }
      for back in stride(from: 1, through: nightsAgo, by: 1) {
        guard let day = calendar.date(byAdding: .day, value: -back, to: now),
          let bed = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: day),
          let morningAfter = calendar.date(byAdding: .hour, value: 8, to: bed)?
            .addingTimeInterval(30 * 60)
        else { continue }
        // The lock started the gap before bed (D76).
        let evening = bed.addingTimeInterval(
          -TimeInterval(state.gap.minutes(forNight: calendar.startOfDay(for: day)) * 60))
        if morningAfter < now {
          log.append(
            Transition(
              at: morningAfter, cause: .windowEnd, blockOn: false, changed: true, home: true,
              inWindow: false, entitled: true))
        }
        // A later week has one night away: named in the chart, and not counted.
        if (later && back == 4) || (scenario == .homeMorningAway && back == 1) {
          log.append(
            Transition(
              at: evening, cause: .windowStart, blockOn: false, changed: false, home: false,
              inWindow: true, entitled: true))
          continue
        }
        log.append(
          Transition(
            at: evening, cause: .windowStart, blockOn: true, changed: true, home: true,
            inWindow: true,
            entitled: true))
        let late = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: evening) ?? evening
        if scenario == .homeMorningGap && back == 1 {
          // Paused for ten minutes after midnight: a gap in last night's bar.
          let pausedAt = late.addingTimeInterval(100 * 60)
          log.append(
            Transition(
              at: pausedAt, cause: .doorStart, blockOn: true, changed: false, home: true,
              inWindow: true, entitled: true, door: .open))
          log.append(
            Transition(
              at: pausedAt.addingTimeInterval(600), cause: .doorEnd, blockOn: true, changed: false,
              home: true, inWindow: true, entitled: true))
        }
        let taps =
          scenario == .homeMorningGap && back == 1
          ? 0 : morning && back == 1 ? 3 : later || morning ? back % 4 : 5 - min(back, 4)
        for tap in 0..<taps {
          log.append(
            Transition(
              at: late.addingTimeInterval(Double(tap) * 1500), cause: .blockScreen,
              blockOn: true, changed: false, home: true, inWindow: true, entitled: true))
        }
      }
      log.sort { $0.at < $1.at }
    }
  }
#endif
