import Foundation
import Observation
import TollCore
import TollData
import TollScreenTime
import UIKit

public enum AppTab: Hashable, Sendable {
  case home, insights, people
}

/// App-wide state: where launch routes (spec §9), the gate's shared state, the signed-in person, and the
/// invite code captured from a link. Screens hold their own UI state in their own models.
@MainActor
@Observable
public final class AppModel {
  public let deps: Dependencies
  public private(set) var route: LaunchRoute?
  public private(set) var me: Me?
  public private(set) var config: TollConfig = .defaults
  public private(set) var gate = SharedGateState()
  public private(set) var tollOpensToday = 0
  public var tab: AppTab = .home
  /// Kept through Welcome and setup so Find your friends opens prefilled (E6.33).
  public var pendingInviteCode: String?
  public var showsSignInSheet = false
  /// A solo user signed into an existing account: ask before merging this phone's history (flows §20).
  public var asksToMergeHistory = false
  private var choseSolo = false
  private var friendsStepShown = false
  private var isReturning = false

  public init(deps: Dependencies) {
    self.deps = deps
  }

  public var isSignedIn: Bool { deps.keychain.string(.sessionToken) != nil }
  public var screenTime: ScreenTimeAuthorization.State { ScreenTimeAuthorization.state }
  public var setupSteps: Int { LaunchRouter.setupSteps(signedIn: isSignedIn, isReturning: isReturning) }

  public func launch() async {
    choseSolo = (try? await deps.store.setting("choseSolo", as: Bool.self)) ?? false
    friendsStepShown = (try? await deps.store.setting("friendsStepShown", as: Bool.self)) ?? false
    let storedReturning = try? await deps.store.setting("isReturning", as: Bool.self)
    let hasBlocks = !((try? await deps.store.blocks()) ?? []).isEmpty
    // A Keychain session with an empty database is a reinstall or a new phone (spec §9 paths).
    isReturning = storedReturning ?? (isSignedIn && !hasBlocks)
    config = await deps.config.load()
    me = await deps.account.cachedMe()
    if me == nil && isSignedIn {
      // A reinstall has a Keychain session but no cached identity; asking first avoids showing You to
      // someone who already has a name and handle.
      await refreshRemote()
    } else {
      await reroute()
      Task { await refreshRemote() }
    }
  }

  /// Recomputes the route from current facts. Every setup step calls this when it finishes.
  public func reroute() async {
    let blocks = (try? await deps.store.blocks()) ?? []
    let home = await deps.network.cachedHome()
    let facts = LaunchFacts(
      hasSession: isSignedIn, choseSolo: choseSolo, hasIdentity: me?.hasIdentity ?? false,
      screenTimeApproved: screenTime == .approved, hasBlocks: !blocks.isEmpty,
      isAlone: me?.school == nil && (home?.friends.isEmpty ?? true), friendsStepShown: friendsStepShown,
      isReturning: isReturning)
    route = LaunchRouter.route(facts)
  }

  /// Toll came to the front: count the open (G-10), run the gate, then refresh what friends see.
  public func foreground() async {
    let math = DayMath(timeZone: deps.clock.timeZone, resetHour: config.gate.dayResetHour)
    tollOpensToday = (try? await deps.store.incrementTollOpens(day: math.day(containing: deps.clock.now))) ?? 0
    await deps.gate.update(config: config)
    let allowed = await NotificationPermission.isAllowed()
    await deps.gate.setNotificationsAllowed(allowed)
    if allowed && isSignedIn { UIApplication.shared.registerForRemoteNotifications() }
    gate = await deps.gate.foreground()
    deps.analytics.send(.appOpen)
  }

  public func setGate(_ state: SharedGateState) { gate = state }

  private func refreshRemote() async {
    guard isSignedIn else { return }
    config = await deps.config.refresh(signedIn: true)
    await deps.gate.update(config: config)
    do {
      me = try await deps.account.refreshMe()
    } catch let error as APIError where error.isUnauthorized {
      await deps.account.signOut()
      me = nil
    } catch {}
    _ = try? await deps.network.refreshHome()
    await reroute()
  }

  // MARK: Transitions from setup

  public func chooseSolo() async {
    choseSolo = true
    try? await deps.store.setSetting("choseSolo", true)
    await reroute()
  }

  public func signedIn(_ session: AuthSession) async {
    me = session.user
    isReturning = !session.isNew
    try? await deps.store.setSetting("isReturning", isReturning)
    if choseSolo, ((try? await deps.store.allEvents()) ?? []).isEmpty == false {
      if session.isNew {
        try? await deps.account.uploadLocalHistory()
      } else {
        asksToMergeHistory = true
      }
    }
    await refreshRemote()
  }

  public func mergeHistory(_ merge: Bool) async {
    asksToMergeHistory = false
    if merge { try? await deps.account.uploadLocalHistory() } else { try? await deps.account.skipLocalHistory() }
  }

  public func updated(_ me: Me) {
    self.me = me
  }

  public func finishFriendsStep() async {
    friendsStepShown = true
    try? await deps.store.setSetting("friendsStepShown", true)
    await reroute()
  }

  public func signedOut() async {
    me = nil
    await reroute()
  }

  public func accountDeleted() async {
    me = nil
    choseSolo = false
    friendsStepShown = false
    isReturning = false
    await reroute()
  }

  // MARK: Links

  /// Invite links are `https://<link host>/i/<CODE>` (E6.33).
  public func handle(url: URL) async {
    let parts = url.pathComponents
    guard let index = parts.firstIndex(of: "i"), index + 1 < parts.count else { return }
    let code = parts[index + 1].uppercased()
    pendingInviteCode = code
    guard route == .home else { return }
    if isSignedIn {
      _ = try? await deps.network.request(code: code)
      pendingInviteCode = nil
      tab = .people
    } else {
      showsSignInSheet = true
    }
  }
}
