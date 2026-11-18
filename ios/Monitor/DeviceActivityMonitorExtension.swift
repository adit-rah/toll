@preconcurrency import DeviceActivity
import Foundation
import TollCore
import TollScreenTime

/// Wakes on the sleep window's edges, the sweep after it, and the door. Keeps under ~6 MB: TollCore
/// only, no database (spec §5). Every wake reconciles, so a late or missing callback is corrected by
/// the next.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    switch activity {
    case .door: Reconciler().run(.doorStart)
    case .sleepSweep: Reconciler().run(.sweepStart)
    default: Reconciler().run(.windowStart)
    }
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    switch activity {
    case .door: Reconciler().run(.doorEnd)
    case .sleepSweep: Reconciler().run(.sweepEnd)
    default: Reconciler().run(.windowEnd)
    }
  }

  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name, activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)
    guard event == .doorUse else { return }
    Reconciler().run(.doorUsed) { DoorRules.usedUp(&$0) }
  }
}
