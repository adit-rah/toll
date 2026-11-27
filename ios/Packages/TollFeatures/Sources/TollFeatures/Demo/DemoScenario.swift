#if DEBUG
  import SwiftUI
  import TollCore
  import TollData
  import TollScreenTime
  import TollUI

  /// Debug builds open straight into a screen with `-TollDemo <scenario>` (docs/renders.md). Release
  /// builds contain none of this.
  enum DemoScenario: String, CaseIterable {
    case empty, welcome, blocklist, ready
    /// Onboarding fitted to sleep (#144): Fit Dusk to your sleep; your sleep found in Health, with
    /// weekends apart, asked, and asked after Health had too few nights; the time around it, as
    /// recommended and with the side after switched off; and Ready after Health.
    case fit
    case sleepFound = "setup-sleep-found"
    case sleepFoundWeekends = "setup-sleep-weekends"
    case sleepAsk = "setup-sleep-ask"
    case around = "setup-around"
    case aroundOff = "setup-around-off"
    case sleepNone = "setup-sleep-none"
    case readyHealth = "ready-health"
    /// One-time flow #1 for people already using Dusk (#144): its card on Tonight, and its sheet on
    /// each step. Settings › Sleep, where sleep and both buffers change later.
    case homeFitCard = "home-fit-card"
    case fitSheet = "fit-sheet"
    case fitSheetSleep = "fit-sheet-sleep"
    case fitSheetAround = "fit-sheet-around"
    /// The same step for someone whose weeks fitted their targets (#145).
    case fitSheetFitted = "fit-sheet-around-fitted"
    case settingsSleep = "settings-sleep"
    /// Each side's small sheet: before sleep from onboarding, after waking from Settings › Sleep.
    case aroundBefore = "setup-around-before"
    case settingsSleepAfter = "settings-sleep-after"
    case screenTime = "screen-time"
    case screenTimeAllowed = "screen-time-allowed"
    case screenTimeDenied = "screen-time-denied"
    /// "Only when I'm home" (D68): a sheet over Tonight, home not set yet.
    case setHome = "set-home"
    case setHomeOff = "set-home-off"
    case setHomeLocation = "set-home-location"
    case setHomeAlways = "set-home-always"
    case setHomeLocationOff = "set-home-location-off"
    /// The map with home already set: "Use anywhere" under it (the audit).
    case setHomeSet = "set-home-set"
    case homeEvening = "home-evening"
    case homeBlocked = "home-blocked"
    case homeAway = "home-away"
    case homeFirstWeek = "home-first-week"
    case homeLastNight = "home-last-night"
    case homeWeek = "home-week"
    case homePaused = "home-paused"
    case homeLocation = "home-location"
    case homeScreenTimeOff = "home-screen-time-off"
    /// The night came back from its record without its apps (#140).
    case homeRecovered = "home-recovered"
    /// A newer TestFlight build wrote the state file: this one only reads it (#140).
    case homeReadOnly = "home-read-only"
    case homeNoBlocks = "home-no-blocks"
    case homeMorning = "home-morning"
    /// Last night's card open in the band (founder, 25 Nov), on an ordinary and a landmark morning.
    case homeMorningOpen = "home-morning-open"
    case homeMorningLandmarkOpen = "home-morning-landmark-open"
    case homeMorningGap = "home-morning-gap"
    case homeMorningAway = "home-morning-away"
    /// The morning after the first night with home not set: the morning card and Tonight's card
    /// together, so a card's place beside the morning card can be seen.
    case homeMorningCard = "home-morning-card"
    /// Tonight's band (`TonightBand`): last night's row under the location note, under Monday's
    /// card on Tuesday, under a one-time flow's card, and open under the home card, which fades out.
    case homeMorningLocation = "home-morning-location"
    case homeMorningGapWeek = "home-morning-gap-week"
    case homeMorningFlow = "home-morning-flow"
    case homeMorningCardOpen = "home-morning-card-open"
    /// The hour before the lock: the heads-up offer waits for tomorrow; on Monday, Monday's card
    /// is the one card.
    case homeNightHour = "home-night-hour"
    case homeNightHourMonday = "home-night-hour-monday"
    /// A weekday at 11 am with Study on: Tonight's one quiet line about it (D68, #89), and Study and
    /// Gym on the day's strip (D75).
    case homeDay = "home-day"
    /// The strip's snippet open (D75): on the night in the evening, on Study at 11 am, and on last
    /// night at 8:10 am with its card already put away.
    case homeStripNight = "home-strip-night"
    case homeStripDay = "home-strip-day"
    case homeStripLastNight = "home-strip-last-night"
    /// The free-week pill's purchase sheet over Tonight (D75), and the hero while a pause is open.
    case homePillPurchase = "home-pill-purchase"
    case homePauseOpen = "home-pause-open"
    case sleepMonday = "sleep-monday"
    case sleepBest = "sleep-best"
    /// Your sky (D79) after 5, 7, 30 and 100 nights, the morning after the last; and Tonight's
    /// morning card on the 30th, a landmark.
    case sleepSky5 = "sleep-sky-5"
    case sleepSky7 = "sleep-sky-7"
    case sleepSky30 = "sleep-sky-30"
    case sleepSky100 = "sleep-sky-100"
    /// The empty sky; 30 nights in each light (evening, night, morning); the second pass at 180
    /// nights; Betelgeuse's night open in its popover; and every name shown, as a tap shows them.
    case sleepSky0 = "sleep-sky-0"
    case sleepSky180 = "sleep-sky-180"
    case sleepSkyStar = "sleep-sky-star"
    case sleepSkyNames = "sleep-sky-names"
    case sleepSkyEvening = "sleep-sky-evening"
    case sleepSkyNight = "sleep-sky-night"
    case sleepSkyMorning = "sleep-sky-morning"
    case homeMorningLandmark = "home-morning-landmark"
    /// Your sleep's measures (#88, `DemoSleep`), and last night's card with Health's sleep and with
    /// the first morning's ask (#86).
    case sleepHealthImproving = "sleep-health-improving"
    case sleepHealthFlat = "sleep-health-flat"
    case sleepHealthNoisy = "sleep-health-noisy"
    case sleepDusk = "sleep-dusk"
    case sleepFew = "sleep-few"
    case homeMorningAsleep = "home-morning-asleep"
    case homeMorningAsleepOpen = "home-morning-asleep-open"
    case homeMorningAskOpen = "home-morning-ask-open"
    /// The picture a landmark shares, at 30 nights, as the share sheet would send it.
    case skyShare = "sky-share"
    /// Home not set (D68): the first evening, then the card the morning after the first night.
    case homeAnywhere = "home-anywhere"
    case homeCard = "home-card"
    /// The heads-up card (#104): home set, the evening after the first night, iOS not asked yet.
    case homeHeadsUp = "home-heads-up"
    /// The gap before bed (D76): Monday evening after it grew from 15 to 30, and the one offer to an
    /// install from before it.
    case homeGapWeek = "home-gap-week"
    case homeGapOffer = "home-gap-offer"
    /// Before bed's helpers (D80), at 10:15 pm in a 30-minute gap: Tonight's capsule, its one card,
    /// the sheet's choices and each page (the tone shown playing, silently), and Settings › Before
    /// bed with their switch.
    case homeBeforeBed = "home-before-bed"
    case homeBeforeBedCard = "home-before-bed-card"
    case beforeBed = "before-bed"
    case beforeBedList = "before-bed-list"
    case beforeBedBreathe = "before-bed-breathe"
    case beforeBedWords = "before-bed-words"
    case purchase, settings, insights
    case settingsAnywhere = "settings-anywhere"
    /// Settings with notifications denied: the heads-up row leaves for iOS Settings (#104).
    case settingsHeadsUpDenied = "settings-heads-up-denied"
    /// Home set, location While Using: the Location row leaves for iOS Settings (the audit).
    case settingsWhileUsing = "settings-while-using"
    /// Settings' How it works sheet, its lines built from the config (#52, #127).
    case settingsHowItWorks = "settings-how-it-works"
    case purchasePending = "purchase-pending"
    case purchaseFailed = "purchase-failed"
    case purchaseRestoreNone = "purchase-restore-none"
    case purchaseDone = "purchase-done"
    case blocks
    /// Blocks on a weekday at 11 am, Study on (#89).
    case blocksDay = "blocks-day"
    /// Four other blocks fold into one row (#110): in the evening, and at 11 am with Study on,
    /// when the row opens by itself.
    case blocksMany = "blocks-many"
    case blocksManyDay = "blocks-many-day"
    /// New block: the kinds, then (`-gym`) Gym picked with its hours and no apps yet (#89).
    case blockNew = "block-new"
    case blockNewGym = "block-new-gym"
    case blockEdit = "block-edit"
    /// Editing Study while it's on, and editing the night (#89).
    case blockEditOn = "block-edit-on"
    case blockNight = "block-night"
    /// Study's place picker, and its delete sheet (#141).
    case blockPlace = "block-place"
    case blockDelete = "block-delete"
    case doorChoosing = "door-choosing"
    case doorWaiting = "door-waiting"
    case doorOpen = "door-open"
    case doorNone = "door-none"
    /// States no scenario showed (#129, #141); `DemoPolish.swift` builds them.
    case doorOpenUsed = "door-open-used"
    case homePauseWaiting = "home-pause-waiting"
    case homeHeldHome = "home-held-home"
    case homeBlockedAnywhere = "home-blocked-anywhere"
    case sleepAfterTrial = "sleep-after-trial"
    case settingsScreenTimeOff = "settings-screen-time-off"
    case settingsLog = "settings-log"
    case welcomeRunning = "welcome-running"
    case welcomeUsed = "welcome-used"
    case welcomeBought = "welcome-bought"

    static var current: DemoScenario? {
      UserDefaults.standard.string(forKey: "TollDemo").flatMap(Self.init(rawValue:))
    }

    /// `-TollWordless YES`: the wordless test's renders (docs/design.md §5).
    static var wordless: Bool { UserDefaults.standard.bool(forKey: "TollWordless") }

    var setupPath: [SetupModel.Step]? {
      let around: [SetupModel.Step] = [.fit, .sleep, .around]
      switch self {
      case .welcome, .welcomeRunning, .welcomeUsed, .welcomeBought: return []
      case .fit: return [.fit]
      case .sleepFound, .sleepFoundWeekends, .sleepAsk, .sleepNone: return [.fit, .sleep]
      case .around, .aroundOff, .aroundBefore: return around
      case .screenTime, .screenTimeAllowed, .screenTimeDenied: return around + [.screenTime]
      case .blocklist: return around + [.screenTime, .blocklist]
      case .ready, .readyHealth: return around + [.screenTime, .blocklist, .ready]
      default: return nil
      }
    }

    /// The set-home sheet's screens under the map.
    var setHomePath: [SetHomeModel.Step]? {
      switch self {
      case .setHome, .setHomeOff, .setHomeSet: []
      case .setHomeLocation: [.location]
      case .setHomeAlways: [.location, .always]
      case .setHomeLocationOff: [.location, .locationOff]
      default: nil
      }
    }

    /// Home not set yet (D68): onboarding's Sleep block has no place.
    var homeNotSet: Bool {
      (setHomePath != nil && self != .setHomeSet)
        || [
          .homeAnywhere, .homeCard, .homeMorningCard, .homeMorningCardOpen, .settingsAnywhere,
          .homeBlockedAnywhere,
        ]
        .contains(self)
    }

    /// The simulator cannot grant Family Controls or answer the location prompt; each screen past
    /// them assumes the answers its board shows. Onboarding never asks for location (D68).
    var screenTime: ScreenTimeAuthorization.State? {
      switch self {
      case .blocklist, .ready, .readyHealth, .screenTimeAllowed: .approved
      case .screenTimeDenied, .homeScreenTimeOff, .settingsScreenTimeOff: .denied
      // Every screen after setup assumes what its board shows: everything working.
      default: isHome ? .approved : nil
      }
    }

    var location: LocationAccess.State? {
      switch self {
      case .setHome, .setHomeLocation, .setHomeAlways, .homeLocation, .setHomeSet,
        .settingsWhileUsing, .homeMorningLocation:
        .whileUsing
      case .setHomeOff: .denied
      case .setHomeLocationOff: .approximate
      case .homeAnywhere, .homeCard, .homeMorningCard, .homeMorningCardOpen, .settingsAnywhere,
        .homeBlockedAnywhere:
        .notDetermined
      default: isHome ? .always : nil
      }
    }
    /// Every screen after setup assumes the heads-up is allowed, unless it shows the asking.
    var notifications: NotificationPermission? {
      switch self {
      case .homeHeadsUp, .homeNightHour, .homeNightHourMonday: .notAsked
      case .settingsHeadsUpDenied: .denied
      default: isHome ? .allowed : nil
      }
    }
    var isDoor: Bool { rawValue.hasPrefix("door") }
    /// The tab the screen is on (D63).
    var tab: DuskTab {
      switch self {
      case _ where self == .insights || rawValue.hasPrefix("sleep-"): .sleep
      case _ where rawValue.hasPrefix("block") && self != .blocklist:
        .blocks
      default: .tonight
      }
    }
    /// The kind a new-block scenario shows already picked.
    var newBlockKind: Block.Kind? { self == .blockNewGym ? .gym : nil }
    /// Weekday scenarios at 11 am, with Study on.
    var isDay: Bool {
      [.homeDay, .homeStripDay, .blocksDay, .blocksManyDay, .blockEditOn].contains(self)
    }
    /// The segment whose snippet the strip opens on (D75): a block, or last night.
    var snippet: String? {
      switch self {
      case .homeStripNight: "sleep"
      case .homeStripDay: "study"
      case .homeStripLastNight: "lastNight"
      default: nil
      }
    }
    /// Screens pushed on the tab's stack, with the screens under them.
    var routes: [HomeRoute] {
      switch self {
      case .settings, .settingsAnywhere, .settingsHeadsUpDenied, .settingsWhileUsing,
        .settingsScreenTimeOff, .settingsHowItWorks:
        [.settings]
      case .settingsSleep, .settingsSleepAfter: [.settings, .sleep]
      case .settingsLog: [.settings, .log]
      case .blockNew, .blockNewGym: [.block(nil)]
      case .blockEdit, .blockEditOn, .blockPlace, .blockDelete: [.block(BlockID("study"))]
      case .blockNight: [.block(BlockID("sleep"))]
      default: []
      }
    }
    /// The door and the purchase are sheets over Tonight.
    var presentsSheet: Bool {
      isDoor || rawValue.hasPrefix("purchase") || setHomePath != nil || helperSheet
        || fitSheetPath != nil || self == .settingsHowItWorks
    }
    var isHome: Bool {
      rawValue.hasPrefix("home-") || rawValue.hasPrefix("sleep-") || rawValue.hasPrefix("block")
        || isDoor || rawValue.hasPrefix("purchase") || rawValue.hasPrefix("settings")
        || setHomePath != nil || self == .insights || helperSheet || fitSheetPath != nil
    }
  }

  struct DemoRoot: View {
    let app: AppModel
    let scenario: DemoScenario

    var body: some View {
      Group {
        if let path = scenario.setupPath {
          DemoSetup(app: app, path: path)
        } else if scenario == .skyShare, let landmark = DemoClock.poster() {
          SkyPoster(landmark: landmark)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .ignoresSafeArea()
        } else if scenario.isHome {
          DemoHome(app: app, scenario: scenario)
        } else {
          TollColor.bg.ignoresSafeArea()
        }
      }
      .environment(\.tollWordless, DemoScenario.wordless)
    }
  }
#endif
