import Foundation
import TollCore
import TollData

/// The heads-up before each night (D68, #104): the rule is `HeadsUp` in TollCore; this hands its
/// plan to iOS and asks iOS once.
extension AppModel {
  func readNotifications() async {
    let permission = await NotificationAdapter.permission()
    if permission != notifications { notifications = permission }
    syncHeadsUp()
  }

  /// Tonight's card and Settings' switch. iOS asks only the first time; after a denial Settings
  /// offers iOS Settings instead. From Tonight's offer, the band then says how it went, once
  /// (#160).
  func turnOnHeadsUp(fromOffer: Bool = false) async {
    send(.edit, [.headsUp(true)])
    if notifications == nil { notifications = await NotificationAdapter.permission() }
    if notifications == .notAsked { notifications = await NotificationAdapter.request() }
    if fromOffer { headsUpTurnedOn = true }
    syncHeadsUp()
  }

  func turnOffHeadsUp() {
    send(.edit, [.headsUp(false)])
  }

  /// Hands iOS the plan when it differs from what it has. Unread permission waits: an empty plan
  /// then would clear notifications that are still right.
  func syncHeadsUp() {
    #if DEBUG
      if DemoScenario.current != nil { return }
    #endif
    guard let notifications else { return }
    let plan = HeadsUp.schedule(
      state, screenTime: screenTime == .approved, permission: notifications, now: Date(),
      calendar: .current, config: config)
    guard plan != scheduledHeadsUps else { return }
    scheduledHeadsUps = plan
    NotificationAdapter.schedule(plan)
  }
}
