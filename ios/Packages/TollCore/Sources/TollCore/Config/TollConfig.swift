import Foundation

/// Every tunable (MVP spec §10). Starting values, expected to change; nothing else holds a number.
public struct TollConfig: Codable, Sendable, Equatable {
  public struct Window: Codable, Sendable, Equatable {
    public init() {}
    /// Window start is wake time minus this many hours.
    public var leadHours = 8.5
  }

  public struct Home: Codable, Sendable, Equatable {
    public init() {}
    public var radiusMeters = 150.0
  }

  public struct Door: Codable, Sendable, Equatable {
    public init() {}
    /// The wait before a pause (D67); cancelling it costs nothing.
    public var waitSeconds = 60
    /// How long every shield lifts for (D67).
    public var minutes = 10
    public var regretSeconds = 120
  }

  public struct Unlocks: Codable, Sendable, Equatable {
    public init() {}
    /// Pauses a week, one pool for every block (D67).
    public var max = 3
    /// The weekday whose night starts a new week of pauses (`Calendar` numbering, 1 = Sunday): 2 is
    /// Monday (D67). Unused pauses don't carry over.
    public var refillWeekday = 2
  }

  public struct Blocks: Codable, Sendable, Equatable {
    public init() {}
    /// The canvas draws seven on Blocks · 8 time windows; windows are the limit that bites (D45).
    public var max = 8
    /// Across every block (D29); iOS refuses a shield of more than 50 by name.
    public var maxApps = 40
    /// Distinct time windows across every block: each needs a window and a sweep schedule, and
    /// DeviceActivity monitors at most 20 (docs/architecture.md).
    public var maxWindows = 8
    /// A block's name fits one line on the block screen's title (#62).
    public var maxNameLength = 24
    /// The hours a new block starts with, by kind, so adding one is a kind, the apps and Save (#89).
    /// Study, Work and Other share 9 to 5 on weekdays: blocks with the same hours share one time
    /// window (D40), so the defaults don't use up the eight.
    public var study = Hours(start: ClockTime(hour: 9), end: ClockTime(hour: 17))
    public var work = Hours(start: ClockTime(hour: 9), end: ClockTime(hour: 17))
    public var gym = Hours(start: ClockTime(hour: 18), end: ClockTime(hour: 19))
    public var other = Hours(start: ClockTime(hour: 9), end: ClockTime(hour: 17))
  }

  /// One default rule: a window on some days.
  public struct Hours: Codable, Sendable, Equatable {
    public var start: ClockTime
    public var end: ClockTime
    public var days: Set<Weekday>

    public init(start: ClockTime, end: ClockTime, days: Set<Weekday> = Weekday.weekdays) {
      self.start = start
      self.end = end
      self.days = days
    }
  }

  public struct Trial: Codable, Sendable, Equatable {
    public init() {}
    /// Two weeks of the Sleep block's nights (D78).
    public var nights = 14
  }

  public struct HeadsUp: Codable, Sendable, Equatable {
    public init() {}
    /// The one notification comes this long before each night (D68).
    public var leadMinutes = 20
    /// Nights scheduled at once, so each still gets its heads-up while the app stays closed.
    public var nightsAhead = 7
  }

  /// The lock starts a gap before bed, and the gap grows with smooth weeks (D76). The weekly rule's
  /// numbers are `datascience/sim/gap_rule.py`'s, so the app does what the simulator measured.
  public struct Gap: Codable, Sendable, Equatable {
    public init() {}
    /// A new install's gap; installs from before D76 keep 0 and are offered this once.
    public var start = 15
    public var step = 15
    /// The weekly rule never grows it past this; a person may choose more by hand.
    public var cap = 60
    public var manualMax = 90
    /// Settings' fixed gap moves in these steps, 0 to `manualMax`.
    public var manualStep = 15
    /// A smooth week: the lock ran at least this many nights, at most `smoothMaxPauses` pauses
    /// started inside the gap, and Screen Time was never off.
    public var smoothMinNights = 4
    public var smoothMaxPauses = 1
    /// A hard week: at least this many pauses started inside the gap.
    public var hardPauses = 2
    /// After Screen Time is switched off, the next this many Mondays don't grow it.
    public var offFreezeWeeks = 2
    /// After an ease, smooth weeks in a row before it grows again.
    public var smoothAfterEase = 2
  }

  /// The buffer after sleep (#144): apps stay locked this long after waking, growing by the same
  /// weekly rule as the gap before sleep, toward its own target.
  public struct After: Codable, Sendable, Equatable {
    public init() {}
    /// A new install's, unless the person moves it. Smaller than the gap before: the morning is
    /// the person's own, so it starts gently.
    public var start = 10
    /// 10, 20, 30: two smooth weeks reach the usual target.
    public var step = 10
    /// What it grows toward when nothing suggests otherwise.
    public var target = 30
    public var manualMax = 60
    public var manualStep = 10
  }

  /// Reading past sleep from Apple Health (#144): the usual time asleep and awake, from the
  /// circular median of recent nights.
  public struct Health: Codable, Sendable, Equatable {
    public init() {}
    /// How far back the estimate reads: four weeks hold both kinds of night several times.
    public var lookbackDays = 28
    /// Fewer nights than this and Dusk asks instead: a week is the least that says "usually".
    public var minNights = 7
    /// Weekends are shown apart when either median differs by this much; less is noise.
    public var weekendSplitMinutes = 45
    /// Each kind of night needs this many for its own median.
    public var minWeekendNights = 3
    /// The usual times are rounded to this, as people say them ("around 11:20 pm").
    public var roundMinutes = 5
    /// A night's samples run from this hour of the evening to this hour the next day.
    public var nightStartHour = 18
    public var nightEndHour = 14
    /// Night records this recent are corrected with Health's sleep (D92's `rev`).
    public var correctDays = 7
  }

  /// Suggestion v0 for the buffers' targets (#144; #145 replaces it with a model-backed rule): a
  /// baseline for everyone, a step more for each sign that sleep is hard to reach, within a cap.
  public struct Suggestion: Codable, Sendable, Equatable {
    public init() {}
    /// Everyone's target before sleep: D76's growing gap.
    public var before = 60
    /// Taking long to fall asleep: in bed to asleep, where the source gives both.
    public var latencyOverMinutes = 30
    public var latencyAdd = 15
    /// Falling asleep at very different times: the standard deviation of onset.
    public var variabilityOverMinutes = 60
    public var variabilityAdd = 15
    /// The suggestion never goes past this; a person may choose up to `gap.manualMax`.
    public var beforeMax = 90
    /// Everyone's target after waking.
    public var after = 30
  }

  public struct Sky: Codable, Sendable, Equatable {
    public init() {}
    /// Nights the lock ran that make a quiet landmark morning, the only times the sky can be
    /// shared (D79).
    public var landmarks = [7, 30, 100, 365]
    /// The hour, on the phone's clock, each of the sky's three lights starts when the screen opens:
    /// the evening's dusk glow, the night's almost none, the morning's pale blue-grey.
    public var eveningFromHour = 16
    public var nightFromHour = 21
    public var morningFromHour = 5
  }

  /// Before bed's three helpers in the gap (D80). The breath is about 6 a minute: the tone rises
  /// while breathing in and falls while breathing out.
  public struct Helpers: Codable, Sendable, Equatable {
    public init() {}
    /// How long the tone plays; Settings › Before bed moves it within `breathRange`.
    public var breathMinutes = 3
    public var breathMinMinutes = 1
    public var breathMaxMinutes = 10
    public var inhaleSeconds = 4.5
    public var exhaleSeconds = 5.5
    /// The tone comes in over this many seconds, and fades over the last `fadeOutSeconds`.
    public var fadeInSeconds = 3.0
    public var fadeOutSeconds = 15.0
    /// A low sine from `lowHz` at the bottom of the breath to `highHz` at the top: soft, not shrill.
    public var lowHz = 196.0
    public var highHz = 262.0
    /// Its loudness at the top of a breath, 0 to 1 of the phone's volume; quieter at the bottom.
    public var loudness = 0.3
    /// How much quieter the bottom of a breath is than the top, 0 to 1.
    public var swell = 0.35

    public var breathRange: ClosedRange<Int> { breathMinMinutes...breathMaxMinutes }
  }

  /// One-time flows for people already using Dusk (#140, `Flows`).
  public struct OneTimeFlows: Codable, Sendable, Equatable {
    public init() {}
    /// None this close to the lock: the heads-up's 20 minutes (D68) belong to the night.
    public var quietBeforeLockMinutes = 20
    /// Offered at most this many times; "Not now" on the last applies its defaults.
    public var offers = 3
  }

  public var window = Window()
  public var home = Home()
  public var door = Door()
  public var unlocks = Unlocks()
  public var trial = Trial()
  public var blocks = Blocks()
  public var headsUp = HeadsUp()
  public var gap = Gap()
  public var after = After()
  public var health = Health()
  public var suggestion = Suggestion()
  public var sky = Sky()
  public var helpers = Helpers()
  public var flows = OneTimeFlows()

  public init() {}

  public static let defaults = TollConfig()

  /// One side's numbers: before sleep is D76's gap; after waking its own (#144).
  public func limits(_ side: TollCore.Gap.Side) -> TollCore.Gap.Limits {
    switch side {
    case .before:
      .init(
        start: gap.start, step: gap.step, target: gap.cap, manualMax: gap.manualMax,
        manualStep: gap.manualStep)
    case .after:
      .init(
        start: after.start, step: after.step, target: after.target,
        manualMax: after.manualMax, manualStep: after.manualStep)
    }
  }
}
