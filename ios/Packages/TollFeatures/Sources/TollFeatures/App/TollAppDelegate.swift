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
    #if DEBUG
      if let demo = DemoLaunch.fromArguments(), let model = try? demo.makeModel() {
        self.model = model
        super.init()
        return
      }
    #endif
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
    // The daily summary carries `route: "people"` when friend requests are waiting and `"home"`
    // otherwise; the shield's local notification carries `"gate"` (flows §17).
    let route = response.notification.request.content.userInfo["route"] as? String
    await opened(route: route)
  }

  private func opened(route: String?) async {
    switch route {
    case "people": model.tab = .people
    case "home": model.tab = .home
    case "gate":
      // A tap that brings Toll to the front runs the gate as the scene turns active. One made with
      // Toll already in front activates nothing, and its wait would not start until the next visit.
      if UIApplication.shared.applicationState == .active { await model.gateTapped() }
    default: break
    }
  }

  public nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    []
  }

  func scheduleBackgroundSync() {
    let identifier = Self.syncTask
    // `submit` is a blocking call to another process; made from launch it would hold the first frame.
    Task.detached(priority: .utility) {
      let request = BGAppRefreshTaskRequest(identifier: identifier)
      request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600)
      try? BGTaskScheduler.shared.submit(request)
    }
  }

  private func runBackgroundSync(_ task: BGTask) async {
    scheduleBackgroundSync()
    await model.deps.gate.foreground(userOpened: false)
    task.setTaskCompleted(success: true)
  }
}
