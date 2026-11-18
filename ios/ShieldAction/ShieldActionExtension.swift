import Foundation
@preconcurrency import ManagedSettings
import TollScreenTime

/// The block screen's two buttons (MVP spec §7). The primary one opens the app, where the door is.
/// Either one reconciles first: a block still up after the window ended comes down at the first tap
/// (B-4, B-5).
final class ShieldActionExtension: ShieldActionDelegate {
  override func handle(
    action: ShieldAction, for application: ApplicationToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    completionHandler(Self.response(to: action))
  }

  override func handle(
    action: ShieldAction, for webDomain: WebDomainToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    completionHandler(Self.response(to: action))
  }

  override func handle(
    action: ShieldAction, for category: ActivityCategoryToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    completionHandler(Self.response(to: action))
  }

  private static func response(to action: ShieldAction) -> ShieldActionResponse {
    let opensDoor = action == .primaryButtonPressed
    Reconciler().run(.blockScreen) { if opensDoor { $0.doorAskedAt = Date() } }
    return opensDoor ? .openParentalControlsApp : .close
  }
}
