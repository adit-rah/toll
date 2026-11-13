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
  /// Whether the Keychain holds a session. Kept here because views ask on every draw and the Keychain
  /// answers from another process; every sign-in and sign-out passes through this model.
  public private(set) var isSignedIn = false
  /// The system's answer about notifications as of the last time Toll came to the front; nil before
  /// the first. Settings shows the way to the Settings app instead of its switches when this is false.
  public private(set) var notificationsAllowed: Bool?
  private var choseSolo = false
  private var friendsStepShown = false
  private var isReturning = false
  private var launched = false
  private var foregrounding = false
  private var foregroundAgain = false
  #if DEBUG
    /// The demo launch seeds the store here, before anything reads it (docs/renders.md).
    var beforeLaunch: (@MainActor () async -> Void)?
  #endif

  public init(deps: Dependencies) {
    self.deps = deps
    isSignedIn = deps.keychain.string(.sessionToken) != nil
  }

  public var screenTime: ScreenTimeAuthorization.State { ScreenTimeAuthorization.state }
  public var setupSteps: Int { LaunchRouter.setupSteps(signedIn: isSignedIn, isReturning: isReturning) }

  public func launch() async {
    #if DEBUG
      await beforeLaunch?()
      isSignedIn = deps.keychain.string(.sessionToken) != nil
    #endif
    // Asked for together: one at a time, each answer waited its turn on a main actor that is busy
    // drawing the first frame, and the screen stays blank until the last one is in.
    async let solo = try? deps.store.setting("choseSolo", as: Bool.self)
    async let shown = try? deps.store.setting("friendsStepShown", as: Bool.self)
    async let returning = try? deps.store.setting("isReturning", as: Bool.self)
    async let stored = try? deps.store.blocks()
    async let loadedConfig = deps.config.load()
    async let cachedMe = deps.account.cachedMe()
    choseSolo = (await solo) ?? false
    friendsStepShown = (await shown) ?? false
    let storedReturning = await returning
    let hasBlocks = !((await stored) ?? []).isEmpty
    // A Keychain session with an empty database is a reinstall or a new phone (spec §9 paths).
    isReturning = storedReturning ?? (isSignedIn && !hasBlocks)
    config = await loadedConfig
    me = await cachedMe
    if me == nil && isSignedIn {
      // A reinstall has a Keychain session but no cached identity; asking first avoids showing You to
      // someone who already has a name and handle.
      await refreshRemote()
    } else {
      await reroute()
      Task { await refreshRemote() }
    }
    launched = true
  }

  /// Recomputes the route from current facts. Every setup step calls this when it finishes.
  public func reroute() async {
    async let stored = try? deps.store.blocks()
    async let cachedHome = deps.network.cachedHome()
    let blocks = (await stored) ?? []
    let home = await cachedHome
    let facts = LaunchFacts(
      hasSession: isSignedIn, choseSolo: choseSolo, hasIdentity: me?.hasIdentity ?? false,
      screenTimeApproved: screenTime == .approved, hasBlocks: !blocks.isEmpty,
      isAlone: me?.school == nil && (home?.friends.isEmpty ?? true), friendsStepShown: friendsStepShown,
      isReturning: isReturning)
    let next = LaunchRouter.route(facts)
    if route != next { route = next }
  }

  /// Toll came to the front: count the open (G-10), run the gate, then refresh what friends see.
  public func foreground() async {
    // The scene turns active while launch is still loading config. That call would count a second open
    // and run the gate on default rules; RootView calls again as soon as launch returns.
    guard launched else { return }
    // A return to Toll while a pass is still running may carry a new shield tap, so it is run again
    // rather than dropped.
    guard !foregrounding else {
      foregroundAgain = true
      return
    }
    foregrounding = true
    defer { foregrounding = false }
    repeat {
      foregroundAgain = false
      await runForeground()
    } while foregroundAgain
  }

  private func runForeground() async {
    async let permission = NotificationPermission.isAllowed()
    let math = DayMath(timeZone: deps.clock.timeZone, resetHour: config.gate.dayResetHour)
    tollOpensToday = (try? await deps.store.incrementTollOpens(day: math.day(containing: deps.clock.now))) ?? 0
    await deps.gate.update(config: config)
    // The gate before the permission answer: the wait card is drawn from this state, and nothing in the
    // gate reads the permission (only the shield's fallback line does).
    setGate(await deps.gate.foreground())
    let allowed = await permission
    await notifications(allowed: allowed)
    deps.analytics.send(.appOpen)
  }

  private func notifications(allowed: Bool) async {
    if notificationsAllowed != allowed { notificationsAllowed = allowed }
    await deps.gate.setNotificationsAllowed(allowed)
    if allowed && isSignedIn { UIApplication.shared.registerForRemoteNotifications() }
  }

  /// The permission changed without Toll leaving the front: the system's own sheet was answered.
  public func recheckNotifications() async {
    let allowed = await NotificationPermission.isAllowed()
    await notifications(allowed: allowed)
  }

  /// A shield notification tapped while Toll is already in front. No activation follows, so nothing
  /// else would read the tap and start its wait. Not counted as an open (G-10): Toll was open.
  public func gateTapped() async {
    guard launched else { return }
    setGate(await deps.gate.foreground())
  }

  /// Where a permission is changed once iOS has stopped asking for it (flows §4, §19).
  public func openSystemSettings() async {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    await UIApplication.shared.open(url)
  }

  /// The wait card hands back the same state every second while it counts down; publishing it again
  /// would redraw everything that reads the gate.
  public func setGate(_ state: SharedGateState) {
    if gate != state { gate = state }
  }

  private func refreshRemote() async {
    guard isSignedIn else { return }
    // Sent together: none depends on another, and in a row they kept sign-in and a reinstall's launch
    // waiting three round trips for the next screen.
    async let freshConfig = deps.config.refresh(signedIn: true)
    async let fetchedMe = fetchMe()
    async let fetchedHome = fetchHomeForRouting()
    let remoteConfig = await freshConfig
    if config != remoteConfig { config = remoteConfig }
    await deps.gate.update(config: config)
    do {
      let fresh = try (await fetchedMe).get()
      if me != fresh { me = fresh }
    } catch let error as APIError where error.isUnauthorized {
      await deps.account.signOut()
      readSession()
      me = nil
    } catch {}
    _ = await fetchedHome
    await reroute()
  }

  private func fetchMe() async -> Result<Me, any Error> {
    do {
      return .success(try await deps.account.refreshMe())
    } catch {
      return .failure(error)
    }
  }

  /// Friends decide the route only until Find your friends has been shown (O-5). After that Home fetches
  /// its own copy as it appears, and one here as well is the same request twice at every launch.
  private func fetchHomeForRouting() async -> HomeResponse? {
    guard !friendsStepShown else { return nil }
    return try? await deps.network.refreshHome()
  }

  private func readSession() {
    let hasSession = deps.keychain.string(.sessionToken) != nil
    if isSignedIn != hasSession { isSignedIn = hasSession }
  }

  // MARK: Transitions from setup

  public func chooseSolo() async {
    choseSolo = true
    try? await deps.store.setSetting("choseSolo", true)
    await reroute()
  }

  public func signedIn(_ session: AuthSession) async {
    readSession()
    // The sheet over Home (flows §20) has done its job; nothing else closes it.
    if showsSignInSheet { showsSignInSheet = false }
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
    readSession()
    me = nil
    await reroute()
  }

  public func accountDeleted() async {
    readSession()
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
