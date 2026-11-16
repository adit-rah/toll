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
      if let demo = DemoLaunch.fromLaunch(), let model = try? demo.makeModel() {
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
    // On the main queue: this closure is written on the main actor, so Swift checks at run time that it
    // runs there. With `using: nil` iOS called it on its own queue and the check trapped, killing every
    // background refresh launch within a second (crash logs of 13 and 15 Nov, ledger A131).
    BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.syncTask, using: .main) { task in
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

  /// Silent pushes refresh data and flush check-ins so silence (N-9) is only real silence. Bounded:
  /// past the system's time for a push the app is killed (`BackgroundWork`).
  public func application(
    _ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]
  ) async -> UIBackgroundFetchResult {
    let model = self.model
    let finished = await BackgroundWork().run {
      await model.deps.gate.foreground(userOpened: false)
      _ = try? await model.deps.network.refreshHome()
    }
    if !finished { log.info("silent push answered at the background budget; work carries on later") }
    return finished ? .newData : .failed
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

  /// Completed exactly once, and in time: a refresh task still open at its expiration, or past the
  /// background budget, gets the app killed (`BackgroundWork`).
  private func runBackgroundSync(_ task: BGTask) async {
    scheduleBackgroundSync()
    let model = self.model
    let work = BackgroundWork()
    // `@Sendable` so it is not a main-actor closure: iOS calls it on a queue of its choosing, and a
    // main-actor one would trap there the same way the launch handler did.
    task.expirationHandler = { @Sendable in work.stop() }
    let finished = await work.run { await model.deps.gate.foreground(userOpened: false) }
    if !finished { log.info("background refresh answered early; work carries on later") }
    task.setTaskCompleted(success: finished)
  }
}
