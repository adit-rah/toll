@preconcurrency import DeviceActivity
import Foundation
import TollCore
import TollScreenTime

/// Wakes on schedule edges, session ends and the daily check-in. Keeps under ~6 MB: TollCore only, no
/// database (spec §6). Every wake reconciles, so a late callback is corrected by the next one.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
  private let reconciler = ShieldReconciler()
  private let spool = Spool()

  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    if activity == .checkin {
      if !reconciler.gateStore.load().blocks.isEmpty { write(.checkin) }
    }
    reconcile("start", activity)
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    reconcile("end", activity)
  }

  /// Only session activities ask for a warning: it is where a session shorter than the platform's
  /// minimum interval ends (`SessionInterval`).
  override func intervalWillEndWarning(for activity: DeviceActivityName) {
    super.intervalWillEndWarning(for: activity)
    reconcile("warning", activity)
  }

  /// A callback never ends a session by itself. Reconciling ends only those whose persisted expiry
  /// has passed, so an early or stray callback cannot cut one short (G-6). The monotonic reading
  /// keeps a clock set back mid-session from holding the shield down (G-9).
  private func reconcile(_ edge: String, _ activity: DeviceActivityName) {
    let ended = reconciler.reconcile(
      now: Date(), timeZone: .current, source: "\(edge):\(activity.rawValue)",
      monotonic: SystemClock().monotonic)
    for session in ended {
      write(
        .sessionEnded, session: session,
        reason: session.activityName == activity.rawValue ? .intervalEnd : .expiry)
    }
  }

  private func write(
    _ kind: SpoolRecord.Kind, session: ActiveSession? = nil,
    reason: SpoolRecord.SessionEndReason? = nil
  ) {
    let now = Date()
    spool.append(
      SpoolRecord(
        kind: kind, at: now, tzOffsetMinutes: GateEvent.offsetMinutes(at: now, in: .current),
        appRef: session?.appRefs.first, appRefs: session?.appRefs, sessionMinutes: session?.minutes,
        sessionID: session?.id, reason: reason))
  }
}
