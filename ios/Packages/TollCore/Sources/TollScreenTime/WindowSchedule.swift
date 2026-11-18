#if os(iOS)
  @preconcurrency import DeviceActivity
  import Foundation
  import TollCore

  /// The DeviceActivity schedules that wake the monitor at the window's edges (spec §6). They only
  /// wake it; what is shielded is always decided by `Reconcile`.
  public enum WindowSchedule {
    /// The sweep starts a minute after the window ends and lasts the platform's minimum.
    static let sweepDelayMinutes = 1

    public static func set(_ window: SleepWindow?) throws {
      let center = DeviceActivityCenter()
      guard let window, window.isValid else {
        center.stopMonitoring([.sleepWindow, .sleepSweep])
        return
      }
      try center.startMonitoring(
        .sleepWindow,
        during: DeviceActivitySchedule(
          intervalStart: window.start.components, intervalEnd: window.end.components, repeats: true)
      )
      let sweepStart = window.end.adding(minutes: sweepDelayMinutes)
      try center.startMonitoring(
        .sleepSweep,
        during: DeviceActivitySchedule(
          intervalStart: sweepStart.components,
          intervalEnd: sweepStart.adding(minutes: SleepWindow.minimumMinutes).components,
          repeats: true))
    }
  }
#endif
