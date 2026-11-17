@preconcurrency import CoreLocation
import TollCore

/// Location permission and the one reading setup takes to place home (spec §7 Home, §9).
@MainActor
public final class LocationAccess {
  public enum State: Sendable, Equatable {
    case notDetermined, whileUsing, always, denied
    /// Approximate location: region monitoring does not run at all (decisions D10).
    case approximate
  }

  private let manager = CLLocationManager()

  public init() {}

  public var state: State {
    switch manager.authorizationStatus {
    case .notDetermined: return .notDetermined
    case .denied, .restricted: return .denied
    default:
      if manager.accuracyAuthorization == .reducedAccuracy { return .approximate }
      return manager.authorizationStatus == .authorizedAlways ? .always : .whileUsing
    }
  }

  /// iOS asks for While Using first; Always comes as a second prompt (decisions §5 finding 5).
  public func request() {
    switch manager.authorizationStatus {
    case .notDetermined: manager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse: manager.requestAlwaysAuthorization()
    default: break
    }
  }

  /// The first fix good enough to centre a region on, or nil after `seconds`.
  public func here(radiusMeters: Double, within seconds: Double = 20) async -> HomePoint? {
    await withTaskGroup(of: HomePoint?.self) { group in
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
  nonisolated private static func firstFix(radiusMeters: Double) async -> HomePoint? {
    do {
      for try await update in CLLocationUpdate.liveUpdates() {
        guard let location = update.location, location.horizontalAccuracy >= 0,
          location.horizontalAccuracy <= radiusMeters / 3
        else { continue }
        return HomePoint(
          latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
          radiusMeters: radiusMeters)
      }
    } catch {}
    return nil
  }
}
