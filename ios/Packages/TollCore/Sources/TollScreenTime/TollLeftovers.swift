#if os(iOS)
  @preconcurrency import DeviceActivity
  import Foundation
  @preconcurrency import ManagedSettings
  import TollCore

  /// What Toll left on a phone that upgrades to this app (decisions D28): its shields, its schedules
  /// and its App Group files. Nothing here would ever be touched again otherwise, and Toll's shields
  /// would stay up for good. Safe to run on every launch: each step does nothing once done.
  public enum TollLeftovers {
    static var tollStore: ManagedSettingsStore.Name { ManagedSettingsStore.Name("blocks") }
    static let tollFiles = ["gate-state.json", "spool.jsonl", "tokens.json"]

    public static func clear() {
      ManagedSettingsStore(named: tollStore).clearAllSettings()
      let center = DeviceActivityCenter()
      let stale = center.activities.filter { !isOurs($0) }
      if !stale.isEmpty { center.stopMonitoring(stale) }
      for name in tollFiles {
        try? FileManager.default.removeItem(at: AppGroup.file(name))
      }
    }

    /// Step 2's single-window names ("sleep.window", "sleep.sweep", "sleep.door") count as leftovers
    /// too: the block engine schedules by window (docs/architecture.md).
    public static func isOurs(_ activity: DeviceActivityName) -> Bool {
      Activity(activity) != .unknown
    }
  }
#endif
