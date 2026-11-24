import Foundation

/// Every change to the shared state, from a screen, an extension or a region event
/// (docs/architecture.md). `Engine.apply` performs it; reconcile then decides what must be true.
public enum Command: Sendable {
  /// Setup's answers: the Sleep block, Home if location is in use, and the trial's start (P-2, P-4).
  case finishSetup(sleep: Block, home: Place?, trialStart: Date)
  /// Add a block, or change one; held while it is active (B-3).
  case saveBlock(Block)
  /// Remove a block; held while it is active. The Sleep block cannot be removed.
  case deleteBlock(BlockID)
  /// Add a place or move one; held while an active block uses it.
  case savePlace(Place)
  /// "Only when I'm home" (D68): save Home and have the Sleep block wait for it; held while it's on.
  case setHome(Place)
  /// "Use anywhere": the Sleep block stops waiting for home; held while it's on (B-3). Home stays
  /// saved, so setting it again opens where it was.
  case useAnywhere
  /// A Tonight card the user put away (#102); it doesn't come back.
  case dismissCard(TonightCard)
  /// Settings' heads-up switch (D68).
  case headsUp(Bool)
  case presence(PlaceID, Presence)
  case location(LocationMode)
  case trialStart(Date)
  case purchased(Bool)
  /// Screen Time access as the app read it (#60).
  case screenTime(Bool)
  /// "Pause": the wait starts (D67).
  case startDoor
  case cancelDoor
  case lockDoor
  /// When the pause was asked for, from the block screen or Tonight; nil clears it.
  case askDoor(Date?)
}

public enum CommandError: Error, Equatable, Sendable {
  case door(DoorRules.Refusal)
  case noSleepBlock
  case sleepBlockCannotBeDeleted
  case tooManyBlocks
  case tooManyWindows
  case tooManyApps
  case tooManyPlaces
  case invalidSchedule
  /// Empty, or longer than the block screen's title holds (#62).
  case invalidName
  case unknownPlace
}
