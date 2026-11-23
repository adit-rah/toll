#if DEBUG
  import Foundation
  import TollCore

  /// The demo's "now", pinned so every render reads as a night whatever the machine's clock says
  /// (#73): 11:40 pm inside Sleep's 10:30 pm – 7:00 am for states during the night, 7:55 pm before it,
  /// 8:10 am for the morning card (#103), on a Monday or a Sunday where the week matters.
  enum DemoClock {
    static func now(for scenario: DemoScenario, today: Date = Date()) -> Date {
      let calendar = Calendar.current
      let night =
        scenario == .homeBlocked || scenario == .homeScreenTimeOff || scenario == .homeAway
        || scenario.isDoor
      // 1 is Sunday, 2 Monday: the latest such day, today included.
      let weekday = scenario == .sleepMonday ? 2 : scenario == .sleepBest ? 1 : nil
      let back = weekday.map { (calendar.component(.weekday, from: today) - $0 + 7) % 7 } ?? 0
      let day = calendar.date(byAdding: .day, value: -back, to: today) ?? today
      let (hour, minute) = scenario.isMorning ? (8, 10) : night ? (23, 40) : (19, 55)
      return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
  }

  extension DemoScenario {
    /// Scenarios set the morning after a night: Tonight's morning card and Your sleep's weeks.
    var isMorning: Bool {
      [.homeMorning, .homeMorningGap, .homeMorningAway, .sleepMonday, .sleepBest].contains(self)
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
      let blocked = scenario == .homeBlocked || scenario == .homeScreenTimeOff || scenario.isDoor
      let night = TimeWindow(start: ClockTime(hour: 22, minute: 30), end: ClockTime(hour: 7))
      state.places = scenario.homeNotSet ? [library] : [home, library]
      state.blocks =
        scenario == .homeNoBlocks
        ? []
        : [
          Block(
            id: BlockID("sleep"), name: Copy.Setup.sleepName, kind: .sleep,
            place: scenario.homeNotSet ? nil : home.id,
            schedule: .everyDay(night), apps: nil, appCount: 4),
          Block(
            id: BlockID("study"), name: "Study", kind: .study, place: library.id,
            schedule: WeeklySchedule(rules: [
              .init(
                days: Weekday.weekdays,
                window: TimeWindow(start: ClockTime(hour: 9), end: ClockTime(hour: 17)))
            ]), apps: nil, appCount: 3),
        ]
      state.presence[home.id] = Presence(isInside: scenario != .homeAway, at: now)
      let firstWeek = scenario == .homeFirstWeek
      let later = scenario == .homeWeek || scenario == .sleepMonday
      let paused = scenario == .homePaused
      let morning = scenario.isMorning
      // Home not set: set up this evening, or the evening before the card's first night ended.
      let nightsAgo =
        scenario == .homeAnywhere || scenario.setHomePath != nil
        ? 0
        : firstWeek || scenario == .homeCard
          ? 1
          : scenario == .homeLastNight
            ? 6 : later ? 20 : paused ? 8 : scenario == .sleepBest ? 6 : morning ? 9 : 4
      // A personal best needs weeks before this one, which only the night log still holds.
      let setupAgo = scenario == .sleepBest ? 27 : nightsAgo
      state.setupFinishedAt =
        setupAgo == 0
        ? now.addingTimeInterval(-3600)
        : calendar.date(byAdding: .day, value: -setupAgo, to: now)
      state.trial.start = state.setupFinishedAt
      state.trial.purchased = later || morning
      if scenario == .homePaused {
        state.trial.start = calendar.date(byAdding: .day, value: -8, to: now)
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
        if scenario == .doorWaiting || scenario == .doorOpen {
          // The pause's countdowns run on the real clock, so its times do too.
          let real = Date()
          var door = Door(waitEndsAt: real.addingTimeInterval(scenario == .doorWaiting ? 54 : -48))
          if scenario == .doorOpen {
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
      for back in stride(from: 1, through: nightsAgo, by: 1) {
        guard let day = calendar.date(byAdding: .day, value: -back, to: now),
          let evening = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: day),
          let morningAfter = calendar.date(byAdding: .hour, value: 8, to: evening)?
            .addingTimeInterval(30 * 60)
        else { continue }
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
