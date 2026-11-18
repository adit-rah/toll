@preconcurrency import CoreLocation
import OSLog
import TollCore

/// Region monitoring for home (spec §6, decisions D10). Region events relaunch the app when it is
/// closed, as long as it holds Always: so `watch` runs at every launch, before anything else waits.
public actor HomeRegion {
  public static let shared = HomeRegion()

  static let monitorName = "home"
  static let identifier = "home"

  private var opening: Task<CLMonitor, Never>?
  /// From iOS 18, Always only takes effect while a session asking for it is held.
  private var session: CLServiceSession?
  private let logger = Logger(subsystem: "com.advan.toll", category: "home")

  /// Only one monitor per name may be open in a process; every caller shares this one.
  private func monitor() async -> CLMonitor {
    if let opening { return await opening.value }
    let task = Task { await CLMonitor(Self.monitorName) }
    opening = task
    return await task.value
  }

  /// Delivers each change in presence for as long as the app runs.
  public func watch(_ onChange: @escaping @Sendable (Presence) async -> Void) async {
    if session == nil { session = CLServiceSession(authorization: .always) }
    let monitor = await monitor()
    do {
      for try await event in await monitor.events where event.identifier == Self.identifier {
        guard let presence = Self.presence(event) else { continue }
        logger.info("home event inside=\(presence.isHome)")
        await onChange(presence)
      }
    } catch {
      logger.error("home events ended: \(error.localizedDescription, privacy: .public)")
    }
  }

  /// What the system last decided, for a launch that missed the event itself.
  public func current() async -> Presence? {
    guard let record = await monitor().record(for: Self.identifier) else { return nil }
    return Self.presence(record.lastEvent)
  }

  /// The point being watched, to compare with the settings.
  public func watched() async -> HomePoint? {
    guard let record = await monitor().record(for: Self.identifier),
      let circle = record.condition as? CLMonitor.CircularGeographicCondition
    else { return nil }
    return HomePoint(
      latitude: circle.center.latitude, longitude: circle.center.longitude,
      radiusMeters: circle.radius)
  }

  public func set(_ home: HomePoint?) async {
    let monitor = await monitor()
    await monitor.remove(Self.identifier)
    guard let home else { return }
    let center = CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
    await monitor.add(
      CLMonitor.CircularGeographicCondition(center: center, radius: home.radiusMeters),
      identifier: Self.identifier)
  }

  private static func presence(_ event: CLMonitor.Event) -> Presence? {
    switch event.state {
    case .satisfied: Presence(isHome: true, at: event.date)
    case .unsatisfied: Presence(isHome: false, at: event.date)
    default: nil
    }
  }
}
