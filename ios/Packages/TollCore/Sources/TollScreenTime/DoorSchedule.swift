#if os(iOS)
  @preconcurrency import DeviceActivity
  import Foundation
  import TollCore

  /// The door's DeviceActivity (spec §6): an interval from the end of the wait, with a usage
  /// threshold on the chosen app. Its start opens the door, the threshold or its end closes it. Both
  /// only wake the monitor; `DoorRules` decides.
  public enum DoorSchedule {
    public static func start(_ door: Door, config: TollConfig) throws {
      guard let app = DoorApp.token(from: door.app) else { return }
      let calendar = Calendar.current
      let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
      let end = door.waitEndsAt.addingTimeInterval(DoorRules.intervalSeconds(config))
      let schedule = DeviceActivitySchedule(
        intervalStart: calendar.dateComponents(parts, from: door.waitEndsAt),
        intervalEnd: calendar.dateComponents(parts, from: end), repeats: false)
      let use = DeviceActivityEvent(
        applications: [app], threshold: DateComponents(minute: config.door.minutes))
      try DeviceActivityCenter().startMonitoring(.door, during: schedule, events: [.doorUse: use])
    }

    public static func stop() {
      DeviceActivityCenter().stopMonitoring([.door])
    }
  }
#endif
