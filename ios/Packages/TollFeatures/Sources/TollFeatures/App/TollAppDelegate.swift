import BackgroundTasks
import Foundation
import OSLog
import TollCore
import TollData
import UIKit
import UserNotifications

/// UIKit entry points SwiftUI does not cover: push tokens, silent pushes, notification taps, background
/// refresh. Owns the one `AppModel`.
@MainActor
public final class TollAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  public static let syncTask = "com.advan.toll.sync"
  private let log = Logger(subsystem: "com.advan.toll", category: "app")
  public let model: AppModel

  public override init() {
    let deps: Dependencies
    do {
      deps = try Dependencies.live()
    } catch {
      // The database could not open; keep the gate usable from memory rather than crash (G-8).
      Logger(subsystem: "com.advan.toll", category: "app").fault("live store failed: \(error)")
      deps = (try? Dependencies.preview()) ?? Self.unreachable()
    }
    model = AppModel(deps: deps)
    super.init()
  }

  private static func unreachable() -> Dependencies {
    fatalError("in-memory SQLite failed to open")
  }

  public func application(
    _ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.syncTask, using: nil) { task in
      // The system hands the task over once and completes it from wherever we finish; not Sendable.
      nonisolated(unsafe) let task = task
      Task { @MainActor in await self.runBackgroundSync(task) }
    }
    scheduleBackgroundSync()
    return true
  }

  public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
    let hex = token.map { String(format: "%02x", $0) }.joined()
    Task { try? await model.deps.account.registerDevice(pushToken: hex) }
  }

  /// Silent pushes refresh data and flush check-ins so silence (N-9) is only real silence.
  public func application(
    _ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]
  ) async -> UIBackgroundFetchResult {
    await model.deps.gate.foreground(userOpened: false)
    _ = try? await model.deps.network.refreshHome()
    return .newData
  }

  public nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    // The daily summary carries `route: "people"` when friend requests are waiting (flows §17).
    let hasRequests = response.notification.request.content.userInfo["route"] as? String == "people"
    await MainActor.run { if hasRequests { model.tab = .people } }
  }

  public nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    []
  }

  func scheduleBackgroundSync() {
    let request = BGAppRefreshTaskRequest(identifier: Self.syncTask)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600)
    try? BGTaskScheduler.shared.submit(request)
  }

  private func runBackgroundSync(_ task: BGTask) async {
    scheduleBackgroundSync()
    await model.deps.gate.foreground(userOpened: false)
    task.setTaskCompleted(success: true)
  }
}
