@preconcurrency import DeviceActivity
import Foundation
import TollCore
import TollScreenTime

/// Wakes on every block window's edges, the sweep after each, the week's turn (#127) and the door. Keeps under ~6 MB:
/// TollCore only (spec §5). Every wake reconciles, so a late or missing callback is corrected by the
/// next; names that are not ours are stopped (decisions D28). A sweep's start also records the night
/// that just ended, reading only the end of each log (#140).
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    switch Activity(activity) {
    case .window: Coordinator.live().wake(.windowStart)
    case .sweep: Coordinator.live().wake(.sweepStart).recordNight()
    case .turn: Coordinator.live().turn()
    case .door: Coordinator.live().wake(.doorStart)
    case .unknown: DeviceActivityCenter().stopMonitoring([activity])
    }
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    switch Activity(activity) {
    case .window: Coordinator.live().wake(.windowEnd)
    case .sweep: Coordinator.live().wake(.sweepEnd)
    // A second chance, should the start come before the first unlock.
    case .turn: Coordinator.live().turn()
    case .door: Coordinator.live().wake(.doorEnd)
    case .unknown: DeviceActivityCenter().stopMonitoring([activity])
    }
  }

  /// The door's warning is its timer: it fires at the door's minutes (D31).
  override func intervalWillEndWarning(for activity: DeviceActivityName) {
    super.intervalWillEndWarning(for: activity)
    if Activity(activity) == .door { Coordinator.live().wake(.doorEnd) }
  }
}
