import Foundation
import Observation
import TollCore
import TollData

/// "Only when I'm home", offered after the first night from Tonight's card and from Settings (D68):
/// the map, then the location prompts, then Always if it's still While Using. Home is saved once, at
/// the end; leaving halfway changes nothing.
@MainActor
@Observable
final class SetHomeModel {
  enum Step: Hashable, CaseIterable {
    case location, always, locationOff
  }

  /// The progress bar counts the map and the location prompts; Always is part of location.
  static let mapStep = 1
  static let locationStep = 2
  static let questions = 2

  let app: AppModel
  var path: [Step]
  /// Home is being dragged under the circle (the canvas's "Move").
  var moving = false
  var home: Place?
  /// Demo launches place home themselves: the simulator has no one to answer the prompt.
  var placesHome = true
  private(set) var locating = false
  private(set) var noFix = false
  /// iOS shows the Always prompt once; after that only Settings can change it.
  private(set) var askedAlways = UserDefaults.standard.bool(forKey: "askedAlways")
  @ObservationIgnored private let done: () -> Void

  init(app: AppModel, path: [Step] = [], done: @escaping () -> Void = {}) {
    self.app = app
    self.path = path
    self.done = done
    // A home already set opens where it is, so this moves it rather than adding another.
    home = app.draftPlace(app.sleepDraft?.place)
  }

  func go(_ step: Step) { path.append(step) }

  /// The map was dragged: home follows its centre.
  func moveHome(latitude: Double, longitude: Double) {
    guard var place = home else { return }
    place.latitude = latitude
    place.longitude = longitude
    home = place
  }

  // MARK: The map

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

  /// Location is off or approximate: no circle can be drawn, and only Settings can change it.
  var mapBlocked: Bool { app.location == .denied || app.location == .approximate }

  /// "This is home": with Always already, nothing more to ask.
  func homeChosen() {
    moving = false
    if app.location == .always { finish() } else { go(.location) }
  }

  // MARK: Location

  /// Settled once Always is granted or iOS will not ask again (decisions D8).
  var locationSettled: Bool {
    switch app.location {
    case .always, .denied, .approximate: true
    case .whileUsing: askedAlways
    case .notDetermined: false
    }
  }

  /// While Using first if the map didn't get it, then the one Always prompt.
  func allowLocation() {
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

  /// After the prompts (the canvas): While Using gets one more screen asking for Always; anything
  /// short of Always and Precise says what that means.
  func afterLocation() {
    switch app.location {
    case .always: finish()
    case .whileUsing: go(.always)
    case .approximate, .denied, .notDetermined: go(.locationOff)
    }
  }

  /// Home is saved even short of Always: the night then runs on its hours anywhere and Tonight says
  /// how to fix it (D37), and Always later needs nothing more from the user.
  func finish() {
    if let home { app.setHome(home) }
    done()
  }

  func cancel() { done() }
}
