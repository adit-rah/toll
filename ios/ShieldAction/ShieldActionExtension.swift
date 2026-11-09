import Foundation
@preconcurrency import ManagedSettings
import TollCore
import TollScreenTime
import UserNotifications

/// "Open Toll" and "Dismiss" on the shield (G-1, G-2). Writes one spool line and responds; nothing else
/// runs here (spec §11.1).
final class ShieldActionExtension: ShieldActionDelegate {
  private let registry = TokenRegistry()
  private let spool = Spool()

  override func handle(
    action: ShieldAction, for application: ApplicationToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    let ref = registry.ref(for: application)
    record(
      action, ref: ref, token: ref == nil ? TokenRegistry.encode(application) : nil,
      kind: .application)
    respond(to: action, completionHandler)
  }

  override func handle(
    action: ShieldAction, for webDomain: WebDomainToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    let ref = registry.ref(for: webDomain)
    record(
      action, ref: ref, token: ref == nil ? TokenRegistry.encode(webDomain) : nil, kind: .webDomain)
    respond(to: action, completionHandler)
  }

  override func handle(
    action: ShieldAction, for category: ActivityCategoryToken,
    completionHandler: @escaping (ShieldActionResponse) -> Void
  ) {
    let ref = registry.ref(for: category)
    record(
      action, ref: ref, token: ref == nil ? TokenRegistry.encode(category) : nil, kind: .category)
    respond(to: action, completionHandler)
  }

  private func record(_ action: ShieldAction, ref: AppRef?, token: Data?, kind: TokenKind) {
    let now = Date()
    spool.append(
      SpoolRecord(
        kind: .blockHit, at: now, tzOffsetMinutes: GateEvent.offsetMinutes(at: now, in: .current),
        appRef: ref,
        token: token, tokenKind: token == nil ? nil : kind,
        via: action == .primaryButtonPressed ? .open : .dismiss))
  }

  private func respond(
    to action: ShieldAction, _ completion: @escaping (ShieldActionResponse) -> Void
  ) {
    guard action == .primaryButtonPressed else {
      completion(.close)
      return
    }
    if #available(iOS 26.5, *) {
      completion(.openParentalControlsApp)
      return
    }
    // Below 26.5 the supported route is a local notification the user taps (spec §6). The short delay
    // before `.defer` lets the notification register.
    let content = UNMutableNotificationContent()
    content.title = Copy.Shield.notificationTitle
    content.interruptionLevel = .timeSensitive
    content.userInfo = ["route": "gate"]
    let request = UNNotificationRequest(identifier: "toll.gate", content: content, trigger: nil)
    // The system calls this handler once and expects it on any queue; it is not annotated Sendable.
    nonisolated(unsafe) let respond = completion
    UNUserNotificationCenter.current().add(request) { _ in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { respond(.defer) }
    }
  }
}
