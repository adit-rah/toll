#if DEBUG
  import Foundation
  import TollCore

  /// A believable state and week for each demo scenario, built around the time of the render so the
  /// lines read the same whenever it runs: Sleep at Home, Study at a library, five nights of log.
  struct DemoFixture {
    var state = DuskState()
    var log: [Transition] = []

    init(scenario: DemoScenario, now: Date) {
      let calendar = Calendar.current
      let minute =
        calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
      let home = Place(
        id: PlaceID("home"), name: Copy.Setup.homeName, latitude: 51.5246, longitude: -0.0786,
        radiusMeters: 150)
      let library = Place(
        id: PlaceID("library"), name: "Robarts Library", latitude: 43.6644, longitude: -79.3995,
        radiusMeters: 150)
      // Starts three hours from now, or is on now, whatever the clock says.
      let blocked = scenario == .homeBlocked || scenario.isDoor
      let startHour = blocked ? minute / 60 : (minute / 60 + 3) % 24
      let night = TimeWindow(
        start: ClockTime(hour: startHour, minute: blocked ? 0 : 30),
        end: ClockTime(hour: startHour).adding(minutes: 8 * 60 + 30))
      state.places = [home, library]
      state.blocks = [
        Block(
          id: BlockID("sleep"), name: Copy.Setup.sleepName, kind: .sleep, place: home.id,
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
      let nightsAgo = firstWeek ? 1 : scenario == .homeLastNight ? 6 : later ? 20 : 4
      state.setupFinishedAt = calendar.date(byAdding: .day, value: -nightsAgo, to: now)
      state.trial.start = state.setupFinishedAt
      state.trial.purchased = later
      if scenario == .homePaused {
        state.trial.start = calendar.date(byAdding: .day, value: -8, to: now)
        state.trial.entitled = false
      }
      if scenario == .homeLocation { state.location = .scheduleOnly }
      if blocked {
        state.runtime.active[BlockID("sleep")] = calendar.date(byAdding: .hour, value: 8, to: now)
        state.doorAskedAt = scenario.isDoor ? now : nil
        state.unlocks.spent = scenario == .doorNone ? 3 : 1
        state.unlocks.cleanNights = 3
        if scenario == .doorWaiting || scenario == .doorOpen {
          var door = Door(
            app: Data(), waitEndsAt: now.addingTimeInterval(scenario == .doorWaiting ? 84 : -48))
          if scenario == .doorOpen {
            door.openedAt = now.addingTimeInterval(-48)
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
      for back in 1...nightsAgo {
        // A later week has one night away: drawn as a dash.
        if later && back == 4 { continue }
        guard let evening = calendar.date(byAdding: .day, value: -back, to: now) else { continue }
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
