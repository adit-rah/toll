@preconcurrency import FamilyControls
import Foundation
import Observation
import TollCore
import TollData
import TollScreenTime

/// Onboarding's draft (D68): the shortest path to a first locked night. When you get up, Screen Time,
/// the apps, then Ready; home comes later, from Tonight or Settings (`SetHomeModel`). Nothing reaches
/// the shared state until Ready is done, so leaving halfway arms nothing.
@MainActor
@Observable
final class SetupModel {
  enum Step: Hashable, CaseIterable {
    case wake, screenTime, blocklist, ready

    /// The progress bar counts the three questions; Ready is not one.
    var number: Int? {
      switch self {
      case .wake: 1
      case .screenTime: 2
      case .blocklist: 3
      case .ready: nil
      }
    }

    static let questions = 3
  }

  let app: AppModel
  var path: [Step]
  private(set) var wake = ClockTime(hour: 7)
  private(set) var start: ClockTime
  private var startMoved = false
  /// Friday and Saturday nights end later (the canvas's "Different on weekends").
  var weekendsDiffer = false
  private(set) var weekendWake = ClockTime(hour: 9)
  var selection = FamilyActivitySelection()

  init(app: AppModel, path: [Step] = []) {
    self.app = app
    self.path = path
    start = TimeWindow(wake: ClockTime(hour: 7), leadHours: app.config.window.leadHours).start
  }

  var window: TimeWindow { TimeWindow(start: start, end: wake) }

  var weekendWindow: TimeWindow {
    TimeWindow(wake: weekendWake, leadHours: app.config.window.leadHours)
  }

  var schedule: WeeklySchedule {
    guard weekendsDiffer else { return .everyDay(window) }
    return WeeklySchedule(rules: [
      .init(days: Weekday.schoolNights, window: window),
      .init(days: Weekday.weekendNights, window: weekendWindow),
    ])
  }

  func setWeekendWake(_ time: ClockTime) { weekendWake = time }

  /// The trial's start from the Keychain: a reinstall keeps it (P-4).
  let trialStart = TrialClock().start

  /// What Welcome and Ready can promise this phone (#46).
  func offer(now: Date, calendar: Calendar = .current) -> Trial.Offer {
    Trial.offer(
      start: trialStart, purchased: app.state.trial.purchased, now: now, sleep: schedule,
      calendar: calendar, config: app.config)
  }

  func setWake(_ time: ClockTime) {
    wake = time
    if !startMoved { start = TimeWindow(wake: time, leadHours: app.config.window.leadHours).start }
  }

  func setStart(_ time: ClockTime) {
    start = time
    startMoved = true
  }

  func go(_ step: Step) { path.append(step) }

  // MARK: Screen Time

  var screenTimeReady: Bool { app.screenTime == .approved }

  /// Screen Time alone (D68): location is asked only when home is set, after the first night.
  func allow() async {
    if app.screenTime != .approved { await app.requestScreenTime() }
  }

  // MARK: Blocklist and finish

  /// At least one thing to block, and no more than the limit across blocks (D29).
  var blocklistReady: Bool {
    !Blocklist.isEmpty(selection) && Blocklist.items(selection) <= app.config.blocks.maxApps
  }

  func blocklistChosen() { go(.ready) }

  /// The Sleep block with no place: until home is set it runs on its hours wherever the phone is
  /// (D68, the engine's D37 path). Built here, sent once at the end.
  var sleepBlock: Block {
    Block(
      name: Copy.Setup.sleepName, kind: .sleep, place: nil, schedule: schedule,
      apps: Blocklist.encode(selection))
  }

  func finish() { app.finishSetup(sleep: sleepBlock, home: nil) }
}
