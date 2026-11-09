import Testing

@testable import TollCore

/// Every path in `toll-user-flows.md` §0 and the table in spec §9.
struct LaunchRouteTests {
  @Test func noSessionAndNoChoiceShowsWelcome() {
    #expect(LaunchRouter.route(LaunchFacts()) == .welcome)
  }

  @Test func newSignedInAccountGoesThroughEveryStep() {
    var f = LaunchFacts(hasSession: true, isAlone: true)
    #expect(LaunchRouter.route(f) == .you)
    f.hasIdentity = true
    #expect(LaunchRouter.route(f) == .permissions)
    f.screenTimeApproved = true
    #expect(LaunchRouter.route(f) == .blocks(returning: false))
    f.hasBlocks = true
    #expect(LaunchRouter.route(f) == .findFriends)
    f.friendsStepShown = true
    #expect(LaunchRouter.route(f) == .home)
  }

  @Test func soloSkipsYouAndFriends() {
    var f = LaunchFacts(choseSolo: true)
    #expect(LaunchRouter.route(f) == .permissions)
    f.screenTimeApproved = true
    f.hasBlocks = true
    #expect(LaunchRouter.route(f) == .home)
  }

  @Test func returningWithSessionInKeychainSkipsWelcomeAndSeesBlockTheseAgain() {
    let f = LaunchFacts(hasSession: true, hasIdentity: true, isReturning: true)
    #expect(LaunchRouter.route(f) == .permissions)
    var granted = f
    granted.screenTimeApproved = true
    #expect(LaunchRouter.route(granted) == .blocks(returning: true))
  }

  @Test func returningWithFriendsSkipsTheFriendsStep() {
    let f = LaunchFacts(
      hasSession: true, hasIdentity: true, screenTimeApproved: true, hasBlocks: true, isAlone: false,
      isReturning: true)
    #expect(LaunchRouter.route(f) == .home)
  }

  @Test func revokedPermissionWhileInstalledIsNotOnboardingOnceBlocksExist() {
    let f = LaunchFacts(hasSession: true, hasIdentity: true, screenTimeApproved: false, hasBlocks: true)
    #expect(LaunchRouter.route(f) == .home)
    let solo = LaunchFacts(choseSolo: true, screenTimeApproved: false, hasBlocks: true)
    #expect(LaunchRouter.route(solo) == .home)
  }

  @Test func progressBarLength() {
    #expect(LaunchRouter.setupSteps(signedIn: true, isReturning: false) == 4)
    #expect(LaunchRouter.setupSteps(signedIn: true, isReturning: true) == 2)
    #expect(LaunchRouter.setupSteps(signedIn: false, isReturning: false) == 2)
  }
}
