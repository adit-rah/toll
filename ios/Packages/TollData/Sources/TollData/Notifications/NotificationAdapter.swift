import Foundation
import TollCore
@preconcurrency import UserNotifications

/// The heads-up before each night, Dusk's one notification (D68, #104). App only: the extensions
/// can't import TollData, so the app reschedules whenever it runs.
@MainActor
public enum NotificationAdapter {
  #if DEBUG
    /// Demo launches stand in for the user's answer: the simulator's prompt would cover the screen.
    public static var simulated: NotificationPermission?
  #endif

  public static func permission() async -> NotificationPermission {
    #if DEBUG
      if let simulated { return simulated }
    #endif
    let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    switch status {
    case .notDetermined: return .notAsked
    case .denied: return .denied
    default: return .allowed
    }
  }

  /// iOS asks once; after a denial only iOS Settings can change the answer.
  public static func request() async -> NotificationPermission {
    #if DEBUG
      if let simulated { return simulated }
    #endif
    // Banners only: the heads-up is quiet (D65), so neither sound nor badge is asked for.
    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
    return await permission()
  }

  /// Replaces everything pending with these. Dusk sends nothing else (D68), so whatever was pending
  /// is an older plan.
  public static func schedule(_ headsUps: [HeadsUp], calendar: Calendar = .current) {
    #if DEBUG
      if simulated != nil { return }
    #endif
    let center = UNUserNotificationCenter.current()
    center.removeAllPendingNotificationRequests()
    for headsUp in headsUps {
      let content = UNMutableNotificationContent()
      content.title = headsUp.title
      content.body = headsUp.body
      // No time zone in the trigger: like the night itself, it follows the phone's clock if the
      // phone travels before the app next runs.
      let when = calendar.dateComponents(
        [.year, .month, .day, .hour, .minute, .second], from: headsUp.at)
      let request = UNNotificationRequest(
        identifier: "headsUp-\(Int(headsUp.at.timeIntervalSince1970))", content: content,
        trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false))
      center.add(request, withCompletionHandler: nil)
    }
  }
}
