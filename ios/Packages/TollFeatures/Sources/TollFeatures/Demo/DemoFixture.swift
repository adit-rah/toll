#if DEBUG
  import Foundation
  import TollCore

  extension DemoScenario {
    /// Scenarios set the morning after a night: Tonight's morning card and Your sleep's weeks.
    var isMorning: Bool {
      [
        .homeMorning, .homeMorningOpen, .homeMorningGap, .homeMorningAway, .homeMorningCard,
        .homeStripLastNight,
        .sleepMonday, .sleepBest,
      ]
      .contains(self) || Self.bandMornings.contains(self)
        || (skyNights != nil && ![.sleepSkyEvening, .sleepSkyNight].contains(self))
    }

    /// What the sky opens with: every name shown, or Betelgeuse's night (Orion's shoulder) open.
    var skyFocus: SkyFocus? {
      switch self {
      case .sleepSkyNames: SkyFocus(everything: true)
      case .sleepSkyStar: SkyFocus(star: 19)
      default: nil
      }
    }

    var isGap: Bool { self == .homeGapOffer || mondaysCard || nightHour }

    /// Before bed's scenarios (D80): Tonight in the gap, with the helpers' sheet over it for some.
    var inGap: Bool { [.homeBeforeBed, .homeBeforeBedCard].contains(self) || helperSheet }
    var helperSheet: Bool { rawValue.hasPrefix("before-bed") }
    var helperPage: Helper? {
      switch self {
      case .beforeBedList: .list
      case .beforeBedBreathe: .breathe
      case .beforeBedWords: .words
      default: nil
      }
    }

    /// Nights the lock has run in Your sky's scenarios (D79), the last of them last night.
    var skyNights: Int? {
      switch self {
      case .sleepSky5: 5
      case .sleepSky7: 7
      case .sleepSky0: 0
      case .sleepSky30, .homeMorningLandmark, .homeMorningLandmarkOpen, .sleepSkyStar,
        .sleepSkyNames, .sleepSkyEvening,
        .sleepSkyNight, .sleepSkyMorning:
        30
      case .sleepSky100: 100
      case .sleepSky180: 180
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
      let pauseOpen = [.doorOpen, .homePauseOpen, .doorOpenUsed].contains(scenario)
      let waiting = scenario == .doorWaiting || scenario == .homePauseWaiting
      let blocked =
        scenario == .homeBlocked || scenario == .homeScreenTimeOff || scenario.isDoor || pauseOpen
        || scenario.inGap || scenario.blockedToo
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
      if [.blocksMany, .blocksManyDay].contains(scenario) {
        for (kind, apps) in [(Block.Kind.work, 5), (.other, 1)] {
          var block = BlockDraft.new(kind)
          block.id = BlockID(Copy.Blocks.kindName(kind).lowercased())
          block.appCount = apps
          state.blocks.append(block)
        }
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
      let paused = scenario == .homePaused || scenario == .sleepAfterTrial
      let morning = scenario.isMorning
      // Home not set: set up this evening, or the evening before the card's first night ended.
      let nightsAgo =
        scenario == .homeAnywhere || scenario.setHomePath != nil
        ? 0
        : firstWeek
          || [.homeCard, .homeMorningCard, .homeMorningCardOpen, .homeHeadsUp].contains(scenario)
          ? 1
          : scenario == .homeLastNight
            ? 13
            : later
              ? 20
              : paused
                ? (scenario == .sleepAfterTrial ? 15 : 8)
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
      // Last night's card was put away; the strip opens it again.
      if scenario == .homeStripLastNight {
        state.lastNightSeen = calendar.startOfDay(for: now.addingTimeInterval(-12 * 3600))
      }
      // A new install locks 30 minutes before sleep (D76) and 15 after waking (#144); the offers
      // are for people from before each.
      state.gap = scenario == .homeGapOffer ? .existing : .newInstall()
      state.after =
        scenario == .homeGapOffer || scenario.fitOffered
        ? .none(target: 30) : .growing(from: 15, to: 30)
      state.after.offered = scenario.fitOffered
      if scenario.mondaysCard {
        state.gap.minutes = 30
        state.gap.change = Gap.Change(
          week: UnlockSupply.week(containing: now, calendar: calendar, config: .defaults),
          from: 15, to: 30)
      }
      if scenario.inGap {
        state.gap.minutes = 30
        // The card shows once; every other scenario has answered it.
        if scenario != .homeBeforeBedCard {
          state.dismissedCards.insert(TonightCard.beforeBed.rawValue)
        }
      }
      if paused {
        state.trial.start = calendar.date(byAdding: .day, value: -15, to: now)
        state.trial.entitled = false
      }
      if scenario == .homeLocation || scenario == .homeMorningLocation {
        state.location = .scheduleOnly
      }
      if scenario == .homeRecovered, let night = state.blocks.firstIndex(where: \.isSleep) {
        state.recoveredAt = now
        state.blocks[night].apps = nil
        state.blocks[night].appCount = 0
      }
      if blocked {
        state.runtime.active[BlockID("sleep")] =
          night.night(startingOn: calendar.startOfDay(for: now), calendar: calendar)?.end
          .addingTimeInterval(TimeInterval(state.after.minutes * 60))
        state.doorAskedAt = scenario.isDoor ? now : nil
        state.unlocks.spent = scenario == .doorNone ? 3 : 1
        state.unlocks.week = UnlockSupply.week(
          containing: now, calendar: calendar, config: .defaults)
        if waiting || pauseOpen {
          // The pause's countdowns run on the real clock, so its times do too; Tonight's hero has
          // no countdown, so it keeps the demo's. A used pause opened past the regret time (D-4).
          let real = scenario == .homePauseOpen ? now : Date()
          let opened: TimeInterval = scenario == .doorOpenUsed ? -200 : -48
          var door = Door(waitEndsAt: real.addingTimeInterval(waiting ? 54 : opened))
          if pauseOpen {
            door.openedAt = real.addingTimeInterval(opened)
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
            at: now.addingTimeInterval(scenario.inGap ? -900 : -3600), cause: .windowStart,
            blockOn: true, changed: true,
            home: true, inWindow: true, entitled: true))
      }
      if scenario == .sleepBest {
        // Weeks of 5, 4 and 5 nights before this one's 6.
        history = (7...27).compactMap {
          Self.recorded($0, before: now, ran: ![9, 12, 15, 17, 18, 22, 25].contains($0))
        }
      }
      if let sky = scenario.skyNights, sky > nightsAgo {
        history = (nightsAgo + 1...sky).compactMap { Self.recorded($0, before: now, ran: true) }
      }
      for back in stride(from: 1, through: nightsAgo, by: 1) {
        guard let day = calendar.date(byAdding: .day, value: -back, to: now),
          let bed = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: day),
          let morningAfter = calendar.date(byAdding: .hour, value: 8, to: bed)?
            .addingTimeInterval(TimeInterval(30 + state.after.minutes) * 60)
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
      polish(scenario)
      log.sort { $0.at < $1.at }
    }

    /// A night the night log kept, `back` nights before `now`: 10:30 pm to 7 am, with a tap or two.
    static func recorded(_ back: Int, before now: Date, ran: Bool) -> PastNight? {
      let calendar = Calendar.current
      guard let day = calendar.date(byAdding: .day, value: -back, to: now),
        let start = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: day)
      else { return nil }
      let end = start.addingTimeInterval(8.5 * 3600)
      return PastNight(
        night: calendar.startOfDay(for: day), ran: ran, start: ran ? start : nil,
        end: ran ? end : nil, locked: ran ? 8.5 * 3600 : 0,
        taps: ran
          ? (0..<(back % 3)).map { start.addingTimeInterval(Double($0 * 40 + 50) * 60) } : [])
    }
  }
#endif
