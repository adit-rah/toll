@preconcurrency import DeviceActivity
import Foundation
import TollCore
import TollScreenTime

/// Wakes on the sleep window's edges and the sweep after it. Keeps under ~6 MB: TollCore only, no
/// database (spec §5). Every wake reconciles, so a late or missing callback is corrected by the next.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    Reconciler().run(activity == .sleepSweep ? .sweepStart : .windowStart)
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    Reconciler().run(activity == .sleepSweep ? .sweepEnd : .windowEnd)
  }
}
