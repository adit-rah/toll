import Foundation
@preconcurrency import ManagedSettings

/// The block screen's two buttons (MVP spec §7). The primary one opens the app, where the door is.
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
    action == .primaryButtonPressed ? .openParentalControlsApp : .close
  }
}
