import Foundation
@preconcurrency import ManagedSettings
import TollCore
import TollScreenTime

/// The block screen's buttons (D32, after Opal): "Never mind" closes; "Open Dusk to pause" opens the app at
/// the pause sheet (D67). Either reconciles first, so a block still up after it should have ended
/// comes down at the first tap (B-4, B-5). "Never mind" taps are what "times it stopped you" counts
/// (D24); "Open Dusk to pause" is logged apart, as asking for a pause (#44). A pause lifts every block, so
/// which app the screen was showing doesn't matter.
final class ShieldActionExtension: ShieldActionDelegate {
  override func handle(
    action: ShieldAction, for application: ApplicationToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    completionHandler(Self.respond(to: action))
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

  private static func respond(to action: ShieldAction) -> ShieldActionResponse {
    let unlocks = action == .secondaryButtonPressed
    if unlocks {
      Coordinator.live().wake(.doorAsked, [.askDoor(Date())])
    } else {
      Coordinator.live().wake(.blockScreen)
    }
    return unlocks ? .openParentalControlsApp : .close
  }
}
