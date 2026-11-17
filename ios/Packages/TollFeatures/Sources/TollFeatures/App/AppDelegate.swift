import UIKit

@MainActor
public final class TollAppDelegate: NSObject, UIApplicationDelegate {
  public let model = AppModel()

  public func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    model.start()
    return true
  }
}
