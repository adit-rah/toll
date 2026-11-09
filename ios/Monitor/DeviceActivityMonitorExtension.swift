@preconcurrency import DeviceActivity
import Foundation
import TollCore
import TollScreenTime

/// Wakes on schedule edges, session thresholds and the daily check-in. Keeps under ~6 MB: TollCore only,
/// no database (spec §6). Every wake reconciles, so a late callback is corrected by the next one.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
  private let reconciler = ShieldReconciler()
  private let spool = Spool()

  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    if activity == .checkin {
      if !reconciler.gateStore.load().blocks.isEmpty { write(.checkin) }
    }
    recordEnded(
      reconciler.reconcile(now: Date(), timeZone: .current, source: "start:\(activity.rawValue)"))
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    if activity.rawValue.hasPrefix("session.") {
      endSession(activity, reason: .intervalEnd)
    } else {
      recordEnded(
        reconciler.reconcile(now: Date(), timeZone: .current, source: "end:\(activity.rawValue)"))
    }
  }

  override func eventDidReachThreshold(
    _ event: DeviceActivityEvent.Name, activity: DeviceActivityName
  ) {
    super.eventDidReachThreshold(event, activity: activity)
    guard event == .sessionThreshold else { return }
    endSession(activity, reason: .threshold)
    DeviceActivityCenter().stopMonitoring([activity])
  }

  private func endSession(_ activity: DeviceActivityName, reason: SpoolRecord.SessionEndReason) {
    if let ended = reconciler.end(sessionNamed: activity.rawValue, now: Date(), timeZone: .current)
    {
      write(.sessionEnded, session: ended, reason: reason)
    }
  }

  private func recordEnded(_ sessions: [ActiveSession]) {
    for session in sessions { write(.sessionEnded, session: session, reason: .expiry) }
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
