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
  case presence(PlaceID, Presence)
  case location(LocationMode)
  case trialStart(Date)
  case purchased(Bool)
  /// Screen Time access as the app read it (#60).
  case screenTime(Bool)
  case startDoor(app: Data)
  case cancelDoor
  case lockDoor
  /// When the door was asked for, and the app the block screen was showing (D41); nil clears it.
  case askDoor(Date?, app: Data? = nil)
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
  case unknownPlace
}
