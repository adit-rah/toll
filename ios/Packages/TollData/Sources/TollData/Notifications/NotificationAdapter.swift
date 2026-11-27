import Foundation
import TollCore
import TollScreenTime
@preconcurrency import UserNotifications

/// The heads-up before each night, Dusk's one notification (D68, #104): asking iOS is the app's.
/// The app reschedules whenever it runs; the monitor only at the week's turn (#127).
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

  /// Replaces everything pending with these (`HeadsUpNotifications`, shared with the monitor).
  public static func schedule(_ headsUps: [HeadsUp], calendar: Calendar = .current) {
    #if DEBUG
      if simulated != nil { return }
    #endif
    HeadsUpNotifications.replace(headsUps, calendar: calendar)
  }
}
