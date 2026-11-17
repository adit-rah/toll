@preconcurrency import FamilyControls
import Foundation
import Observation
import TollCore
import TollData
import TollScreenTime

/// Setup's draft (spec §7 Setup). Nothing reaches the shared state until the keep-open screen is done,
/// so leaving setup halfway arms nothing.
@MainActor
@Observable
final class SetupModel {
  enum Step: Hashable, CaseIterable {
    case wake, home, permissions, keepOpen, ready

    /// The progress bar counts the four questions; Ready is not one.
    var number: Int? {
      switch self {
      case .wake: 1
      case .home: 2
      case .permissions: 3
      case .keepOpen: 4
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
  var home: HomePoint?
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
    start = SleepWindow(wake: ClockTime(hour: 7), leadHours: app.config.window.leadHours).start
  }

  var window: SleepWindow { SleepWindow(start: start, end: wake) }

  func setWake(_ time: ClockTime) {
    wake = time
    if !startMoved { start = SleepWindow(wake: time, leadHours: app.config.window.leadHours).start }
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
      home = await app.locationAccess.here(radiusMeters: app.config.home.radiusMeters)
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

  // MARK: Keep open and finish

  func keepOpenChosen() {
    app.submit(
      SleepSettings(
        window: window, home: locationUsable ? home : nil, keepOpen: KeepOpen.encode(selection)))
    go(.ready)
  }

  func finish() { app.finishSetup() }
}
