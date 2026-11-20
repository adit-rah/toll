@preconcurrency import FamilyControls
import Foundation
import Observation
import TollCore
import TollData
import TollScreenTime

/// Setup's draft (spec §7 Setup). Nothing reaches the shared state until the blocklist is done,
/// so leaving setup halfway arms nothing.
@MainActor
@Observable
final class SetupModel {
  enum Step: Hashable, CaseIterable {
    case wake, home, permissions, always, locationOff, blocklist, ready

    /// The progress bar counts the four questions; Always is part of permissions, Ready is not one.
    var number: Int? {
      switch self {
      case .wake: 1
      case .home: 2
      case .permissions, .always, .locationOff: 3
      case .blocklist: 4
      case .ready: nil
      }
    }

    static let questions = 4
  }

  let app: AppModel
  var path: [Step]
  private(set) var wake = ClockTime(hour: 7)
  private(set) var start: ClockTime
  private var startMoved = false
  /// Friday and Saturday nights end later (the canvas's "Different on weekends").
  var weekendsDiffer = false
  private(set) var weekendWake = ClockTime(hour: 9)
  /// Home is being dragged under the circle (the canvas's "Move").
  var moving = false
  var home: Place?
  /// Demo launches place home themselves: the simulator has no one to answer the prompt.
  var placesHome = true
  private(set) var locating = false
  private(set) var noFix = false
  var selection = FamilyActivitySelection()
  /// iOS shows the Always prompt once; after that only Settings can change it.
  private(set) var askedAlways = UserDefaults.standard.bool(forKey: "askedAlways")

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

  /// The map was dragged: home follows its centre.
  func moveHome(latitude: Double, longitude: Double) {
    guard var place = home else { return }
    place.latitude = latitude
    place.longitude = longitude
    home = place
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

  // MARK: Home

  /// Asks While Using the first time; a later call finds where the user is.
  func locate() async {
    guard placesHome else { return }
    switch app.location {
    case .notDetermined:
      app.locationAccess.requestWhileUsing()
    case .whileUsing, .always:
      guard home == nil, !locating else { return }
      locating = true
      defer { locating = false }
      let radius = app.config.home.radiusMeters
      home = await app.locationAccess.here(radiusMeters: radius).map {
        Place(
          name: Copy.Setup.homeName, latitude: $0.latitude, longitude: $0.longitude,
          radiusMeters: radius)
      }
      noFix = home == nil
    case .denied, .approximate:
      return
    }
  }

  func retryLocate() async {
    noFix = false
    await locate()
  }

  var locationUsable: Bool { app.location == .whileUsing || app.location == .always }

  /// Blocks wait for home only with Always and Precise: the engine's rule, so Ready says what Home
  /// will (D37, #46).
  var blocksAtHome: Bool { AppModel.locationMode(app.location) == .places && home != nil }

  // MARK: Permissions

  var screenTimeReady: Bool { app.screenTime == .approved }

  /// Location is settled once Always is granted or iOS will not ask again (decisions D8).
  var locationSettled: Bool {
    switch app.location {
    case .always, .denied, .approximate: true
    case .whileUsing: askedAlways
    case .notDetermined: false
    }
  }

  /// Runs the system prompts in order: Screen Time, then location.
  func allow() async {
    if app.screenTime != .approved { await app.requestScreenTime() }
    guard app.screenTime == .approved else { return }
    switch app.location {
    case .notDetermined:
      app.locationAccess.requestWhileUsing()
    case .whileUsing where !askedAlways:
      askedAlways = true
      UserDefaults.standard.set(true, forKey: "askedAlways")
      app.locationAccess.request()
    default:
      break
    }
  }

  // MARK: Blocklist and finish

  /// At least one thing to block, and no more than the limit across blocks (D29).
  var blocklistReady: Bool {
    !Blocklist.isEmpty(selection) && Blocklist.items(selection) <= app.config.blocks.maxApps
  }

  func blocklistChosen() { go(.ready) }

  /// The Sleep block, at Home if location is in use (D37). Built here, sent once at the end, so leaving
  /// setup halfway arms nothing.
  var sleepBlock: Block {
    let place = locationUsable ? home : nil
    return Block(
      name: Copy.Setup.sleepName, kind: .sleep, place: place?.id, schedule: schedule,
      apps: Blocklist.encode(selection))
  }

  /// After the prompts (the canvas): While Using gets one more screen asking for Always; anything
  /// short of Always and Precise says what that means before the apps.
  var afterPermissions: Step {
    switch app.location {
    case .always: .blocklist
    case .whileUsing: .always
    case .approximate, .denied, .notDetermined: .locationOff
    }
  }

  func finish() { app.finishSetup(sleep: sleepBlock, home: locationUsable ? home : nil) }
}
