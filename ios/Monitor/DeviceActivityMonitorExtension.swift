@preconcurrency import DeviceActivity
import Foundation

/// Wakes on the sleep window's edges and on door expiry. Keeps under ~6 MB: TollCore only, no
/// database (MVP spec §5). Reconcile arrives with the trigger (§12 step 2).
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {}
