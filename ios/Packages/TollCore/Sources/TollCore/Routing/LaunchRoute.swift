import Foundation

/// Where an app launch lands (spec §9 O-1…O-6, flows §0). Account, device and identity state are
/// independent; each missing piece routes to the one step that supplies it.
public enum LaunchRoute: Equatable, Sendable {
  case welcome
  case you
  case permissions
  case blocks(returning: Bool)
  case findFriends
  case home
}

public struct LaunchFacts: Equatable, Sendable {
  public var hasSession: Bool
  public var choseSolo: Bool
  public var hasIdentity: Bool
  public var screenTimeApproved: Bool
  public var hasBlocks: Bool
  /// Signed in with no friends and no school.
  public var isAlone: Bool
  public var friendsStepShown: Bool
  /// The account existed before this device set up (reinstall or new phone).
  public var isReturning: Bool

  public init(
    hasSession: Bool = false, choseSolo: Bool = false, hasIdentity: Bool = false,
    screenTimeApproved: Bool = false, hasBlocks: Bool = false, isAlone: Bool = false,
    friendsStepShown: Bool = false, isReturning: Bool = false
  ) {
    self.hasSession = hasSession
    self.choseSolo = choseSolo
    self.hasIdentity = hasIdentity
    self.screenTimeApproved = screenTimeApproved
    self.hasBlocks = hasBlocks
    self.isAlone = isAlone
    self.friendsStepShown = friendsStepShown
    self.isReturning = isReturning
  }
}

public enum LaunchRouter {
  public static func route(_ f: LaunchFacts) -> LaunchRoute {
    if !f.hasSession && !f.choseSolo { return .welcome }  // O-1, O-2
    if f.hasSession && !f.hasIdentity { return .you }  // O-3
    // O-4. A phone that already has blocks but lost permission is not onboarding: Home shows
    // "Screen Time is off · Fix" (spec §9 table, flows §19).
    if !f.hasBlocks { return f.screenTimeApproved ? .blocks(returning: f.isReturning) : .permissions }
    if f.hasSession && f.isAlone && !f.friendsStepShown { return .findFriends }  // O-5
    return .home  // O-6
  }

  /// The setup progress bar: four segments for a new signed-in account, two otherwise (ledger A21).
  public static func setupSteps(signedIn: Bool, isReturning: Bool) -> Int {
    signedIn && !isReturning ? 4 : 2
  }
}
