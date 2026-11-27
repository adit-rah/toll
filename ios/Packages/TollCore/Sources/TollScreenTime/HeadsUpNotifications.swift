#if os(iOS)
  import Foundation
  import os
  import TollCore
  @preconcurrency import UserNotifications

  /// Hands iOS the heads-up plan (D68, #104). Here rather than in TollData because the monitor
  /// replans at the week's turn (#127) and may import nothing larger; UserNotifications is a
  /// system framework, so the monitor stays small.
  public enum HeadsUpNotifications {
    /// How long an extension waits for iOS before it returns: its process can end soon after.
    static let patience = DispatchTimeInterval.seconds(2)

    /// Replaces everything pending with these. Dusk sends nothing else (D68), so whatever was
    /// pending is an older plan. With `wait`, returns once iOS has every request, or after
    /// `patience`.
    public static func replace(
      _ headsUps: [HeadsUp], calendar: Calendar = .current, wait: Bool = false
    ) {
      let center = UNUserNotificationCenter.current()
      center.removeAllPendingNotificationRequests()
      let added = DispatchGroup()
      for headsUp in headsUps {
        let content = UNMutableNotificationContent()
        content.title = headsUp.title
        content.body = headsUp.body
        // No time zone in the trigger: like the night itself, it follows the phone's clock if
        // the phone travels before the app next runs.
        let when = calendar.dateComponents(
          [.year, .month, .day, .hour, .minute, .second], from: headsUp.at)
        let request = UNNotificationRequest(
          identifier: "headsUp-\(Int(headsUp.at.timeIntervalSince1970))", content: content,
          trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false))
        added.enter()
        center.add(request) { _ in added.leave() }
      }
      if wait { _ = added.wait(timeout: .now() + patience) }
    }

    /// From the monitor, which can't ask the person: only while iOS allows Dusk's notifications,
    /// so a plan never reaches iOS after the person turned them off there.
    public static func replaceIfAllowed(_ headsUps: [HeadsUp]) {
      let allowed = OSAllocatedUnfairLock(initialState: false)
      let answered = DispatchSemaphore(value: 0)
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        let status = settings.authorizationStatus
        allowed.withLock { $0 = status != .notDetermined && status != .denied }
        answered.signal()
      }
      guard answered.wait(timeout: .now() + patience) == .success, allowed.withLock({ $0 })
      else { return }
      replace(headsUps, wait: true)
    }
  }
#endif
