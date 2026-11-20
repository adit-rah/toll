import Foundation
@preconcurrency import ManagedSettings
import TollCore
import TollScreenTime

/// The block screen's buttons (D32, after Opal): "Never mind" closes; "Unlock in Dusk" opens the app at
/// the door. Either reconciles first, so a block still up after it should have ended comes down at the
/// first tap (B-4, B-5). Taps are what "times it stopped you" counts (D24). The app the screen was
/// showing goes with the request, so the door opens with it chosen (D41).
final class ShieldActionExtension: ShieldActionDelegate {
  override func handle(
    action: ShieldAction, for application: ApplicationToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    completionHandler(Self.respond(to: action, app: DoorApp.encode(application)))
  }

  override func handle(
    action: ShieldAction, for webDomain: WebDomainToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    completionHandler(Self.respond(to: action))
  }

  override func handle(
    action: ShieldAction, for category: ActivityCategoryToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    completionHandler(Self.respond(to: action))
  }

  private static func respond(to action: ShieldAction, app: Data? = nil) -> ShieldActionResponse {
    let unlocks = action == .secondaryButtonPressed
    Coordinator.live().wake(.blockScreen, unlocks ? [.askDoor(Date(), app: app)] : [])
    return unlocks ? .openParentalControlsApp : .close
  }
}
