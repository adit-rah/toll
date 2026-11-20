@preconcurrency import CoreLocation
import TollCore

/// Location permission and the one reading setup takes to place home (spec §7 Home, §9).
@MainActor
public final class LocationAccess: NSObject, CLLocationManagerDelegate {
  public enum State: Sendable, Equatable {
    case notDetermined, whileUsing, always, denied
    /// Approximate location: region monitoring does not run at all (decisions D10).
    case approximate
  }

  private let manager = CLLocationManager()
  /// Runs on the main actor whenever the user answers a prompt or changes the setting.
  public var onChange: (() -> Void)?

  override public init() {
    super.init()
    manager.delegate = self
  }

  nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    Task { @MainActor in self.onChange?() }
  }

  #if DEBUG
    /// Demo launches stand in for the user's answer: the simulator's prompt would cover the screen.
    public static var simulated: State?
  #endif

  public var state: State {
    #if DEBUG
      if let simulated = Self.simulated { return simulated }
    #endif
    switch manager.authorizationStatus {
    case .notDetermined: return .notDetermined
    case .denied, .restricted: return .denied
    default:
      if manager.accuracyAuthorization == .reducedAccuracy { return .approximate }
      return manager.authorizationStatus == .authorizedAlways ? .always : .whileUsing
    }
  }

  /// Settings' two switches, read separately for the Location-Off screen.
  public var isAlways: Bool {
    #if DEBUG
      if let simulated = Self.simulated { return simulated == .always }
    #endif
    return manager.authorizationStatus == .authorizedAlways
  }

  public var isPrecise: Bool {
    #if DEBUG
      if let simulated = Self.simulated { return simulated != .approximate }
    #endif
    return manager.accuracyAuthorization == .fullAccuracy
  }

  /// iOS asks for While Using first; Always comes as a second prompt, once (decisions §5 finding 5).
  public func request() {
    switch manager.authorizationStatus {
    case .notDetermined: manager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse: manager.requestAlwaysAuthorization()
    default: break
    }
  }

  public func requestWhileUsing() {
    if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
  }

  /// Where the user is, to centre a place on.
  public struct Coordinate: Sendable, Equatable {
    public var latitude: Double
    public var longitude: Double
  }

  /// The first fix good enough to centre a region on, or nil after `seconds`.
  public func here(radiusMeters: Double, within seconds: Double = 20) async -> Coordinate? {
    await withTaskGroup(of: Coordinate?.self) { group in
      group.addTask { await Self.firstFix(radiusMeters: radiusMeters) }
      group.addTask {
        try? await Task.sleep(for: .seconds(seconds))
        return nil
      }
      let first = await group.next() ?? nil
      group.cancelAll()
      return first
    }
  }

  /// A fix within a third of the radius, so the region's edge is where the user thinks it is.
  nonisolated private static func firstFix(radiusMeters: Double) async -> Coordinate? {
    do {
      for try await update in CLLocationUpdate.liveUpdates() {
        guard let location = update.location, location.horizontalAccuracy >= 0,
          location.horizontalAccuracy <= radiusMeters / 3
        else { continue }
        return Coordinate(
          latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
      }
    } catch {}
    return nil
  }
}
