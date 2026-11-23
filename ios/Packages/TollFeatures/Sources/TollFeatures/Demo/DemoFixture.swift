#if DEBUG
  import Foundation
  import TollCore

  /// The demo's "now", pinned so every render reads as a night whatever the machine's clock says
  /// (#73): 11:40 pm inside Sleep's 10:30 pm – 7:00 am for states during the night, 7:55 pm before it.
  enum DemoClock {
    static func now(for scenario: DemoScenario, today: Date = Date()) -> Date {
      let night =
        scenario == .homeBlocked || scenario == .homeScreenTimeOff || scenario == .homeAway
        || scenario.isDoor
      return Calendar.current.date(
        bySettingHour: night ? 23 : 19, minute: night ? 40 : 55, second: 0, of: today) ?? today
    }
  }

  /// A believable state and week for each demo scenario, on the boards' night (10:30 pm – 7:00 am):
  /// Sleep at Home, Study at a library, five nights of log.
  struct DemoFixture {
    var state = DuskState()
    var log: [Transition] = []

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
      let later = scenario == .homeWeek
      let paused = scenario == .homePaused
      // Home not set: set up this evening, or the evening before the card's first night ended.
      let nightsAgo =
        scenario == .homeAnywhere || scenario.setHomePath != nil
        ? 0
        : firstWeek || scenario == .homeCard
          ? 1 : scenario == .homeLastNight ? 6 : later ? 20 : paused ? 8 : 4
      state.setupFinishedAt =
        nightsAgo == 0
        ? now.addingTimeInterval(-3600)
        : calendar.date(byAdding: .day, value: -nightsAgo, to: now)
      state.trial.start = state.setupFinishedAt
      state.trial.purchased = later
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
        state.unlocks.cleanNights = 3
        if scenario == .doorWaiting || scenario == .doorOpen {
          // The door's countdowns run on the real clock, so its times do too.
          let real = Date()
          var door = Door(
            app: Data(), waitEndsAt: real.addingTimeInterval(scenario == .doorWaiting ? 84 : -48))
          if scenario == .doorOpen {
            door.openedAt = real.addingTimeInterval(-48)
            door.expiresAt = door.waitEndsAt.addingTimeInterval(300)
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
      for back in stride(from: 1, through: nightsAgo, by: 1) {
        guard let day = calendar.date(byAdding: .day, value: -back, to: now),
          let evening = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: day)
        else { continue }
        // A later week has one night away: named in the chart, and not counted.
        if later && back == 4 {
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
        for tap in 0..<(later ? back % 4 : 5 - min(back, 4)) {
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
