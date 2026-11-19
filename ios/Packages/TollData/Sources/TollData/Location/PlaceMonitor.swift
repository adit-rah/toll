@preconcurrency import CoreLocation
import OSLog
import TollCore

/// The region adapter (docs/architecture.md): one CLMonitor condition per place, keyed by the place's
/// id. Region events relaunch the app when it is closed, as long as it holds Always, so `watch` runs at
/// every launch before anything else waits (decisions D10).
public actor PlaceMonitor {
  public static let shared = PlaceMonitor()

  static let monitorName = "places"

  private var opening: Task<CLMonitor, Never>?
  /// From iOS 18, Always only takes effect while a session asking for it is held.
  private var session: CLServiceSession?
  private let logger = Logger(subsystem: "com.advan.toll", category: "places")

  /// Only one monitor per name may be open in a process; every caller shares this one.
  private func monitor() async -> CLMonitor {
    if let opening { return await opening.value }
    let task = Task { await CLMonitor(Self.monitorName) }
    opening = task
    return await task.value
  }

  /// Delivers each change of presence for as long as the app runs.
  public func watch(_ onChange: @escaping @Sendable (PlaceID, Presence) async -> Void) async {
    if session == nil { session = CLServiceSession(authorization: .always) }
    let monitor = await monitor()
    do {
      for try await event in await monitor.events {
        guard let presence = Self.presence(event) else { continue }
        logger.info("place event inside=\(presence.isInside)")
        await onChange(PlaceID(event.identifier), presence)
      }
    } catch {
      logger.error("place events ended: \(error.localizedDescription, privacy: .public)")
    }
  }

  /// What the system last decided for each watched place, for a launch that missed the event.
  public func current() async -> [PlaceID: Presence] {
    let monitor = await monitor()
    var result: [PlaceID: Presence] = [:]
    for identifier in await monitor.identifiers {
      if let record = await monitor.record(for: identifier),
        let presence = Self.presence(record.lastEvent)
      {
        result[PlaceID(identifier)] = presence
      }
    }
    return result
  }

  /// Watches exactly these places: adds new ones, replaces moved ones, drops the rest. An empty list
  /// (location not in use, D37) stops watching.
  public func sync(_ places: [Place]) async {
    let monitor = await monitor()
    let wanted = Dictionary(uniqueKeysWithValues: places.map { ($0.id.raw, $0) })
    for identifier in await monitor.identifiers where wanted[identifier] == nil {
      await monitor.remove(identifier)
    }
    for (identifier, place) in wanted {
      let record = await monitor.record(for: identifier)
      let circle = record?.condition as? CLMonitor.CircularGeographicCondition
      if let circle, circle.center.latitude == place.latitude,
        circle.center.longitude == place.longitude, circle.radius == place.radiusMeters
      {
        continue
      }
      if record != nil { await monitor.remove(identifier) }
      let center = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
      await monitor.add(
        CLMonitor.CircularGeographicCondition(center: center, radius: place.radiusMeters),
        identifier: identifier)
    }
  }

  private static func presence(_ event: CLMonitor.Event) -> Presence? {
    switch event.state {
    case .satisfied: Presence(isInside: true, at: event.date)
    case .unsatisfied: Presence(isInside: false, at: event.date)
    default: nil
    }
  }
}
