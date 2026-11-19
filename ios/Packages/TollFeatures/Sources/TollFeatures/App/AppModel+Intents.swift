@preconcurrency import FamilyControls
import Foundation
@preconcurrency import ManagedSettings
import TollCore
import TollData
import TollScreenTime

/// What screens ask for. Each is one command, or a few, through `send`.
extension AppModel {
  // MARK: Setup and blocks

  func finishSetup(sleep: Block, home: Place?) {
    let trialStart = TrialClock().begin(now: Date())
    send(.edit, [.finishSetup(sleep: Blocklist.counted(sleep), home: home, trialStart: trialStart)])
  }

  /// A block as the user last chose it: a held edit if one waits (B-3), else what is in force.
  func draft(_ id: BlockID) -> Block? {
    if case .save(let block) = state.pending[id] { return block }
    return state.block(id)
  }

  var sleepDraft: Block? { state.sleepBlock.flatMap { draft($0.id) } }

  /// A place as the user last chose it.
  func draftPlace(_ id: PlaceID?) -> Place? {
    guard let id else { return nil }
    return state.pendingPlaces[id] ?? state.place(id)
  }

  @discardableResult
  func save(_ block: Block) -> CommandError? {
    send(.edit, [.saveBlock(Blocklist.counted(block))])
  }

  @discardableResult
  func save(_ place: Place) -> CommandError? {
    send(.edit, [.savePlace(place)])
  }

  @discardableResult
  func delete(_ block: BlockID) -> CommandError? {
    send(.edit, [.deleteBlock(block)])
  }

  // MARK: Door

  /// "Unlock in Dusk" was tapped on the block screen in the last two minutes, or a door is under way.
  var showsDoor: Bool {
    guard state.isBlocking else { return false }
    if state.door != nil { return true }
    guard let asked = state.doorAskedAt else { return false }
    return Date().timeIntervalSince(asked) < 120
  }

  /// The apps the door can open: every active block's.
  var doorChoices: FamilyActivitySelection {
    var choices = FamilyActivitySelection()
    for block in state.activeBlocks {
      let selection = Blocklist.selection(from: block.apps)
      choices.applicationTokens.formUnion(selection.applicationTokens)
      choices.categoryTokens.formUnion(selection.categoryTokens)
    }
    return choices
  }

  func startDoor(_ app: ApplicationToken) {
    guard let data = DoorApp.encode(app) else { return }
    send(.doorChosen, [.startDoor(app: data)])
  }

  func cancelDoor() { send(.doorCancelled, [.cancelDoor]) }
  func lockDoor() { send(.doorLocked, [.lockDoor]) }
  func dismissDoor() { send(.foreground, [.askDoor(nil)]) }

  /// Home's "Open one app": the same door the block screen opens.
  func askDoor() { send(.foreground, [.askDoor(Date())]) }

  // MARK: Purchase

  func setPurchased(_ purchased: Bool) {
    guard purchased != state.trial.purchased else { return }
    send(.entitlement, [.purchased(purchased)])
  }

  func buy() async -> Purchase.Outcome {
    let outcome = await Purchase.buy()
    if outcome == .purchased { setPurchased(true) }
    return outcome
  }

  func restore() async -> Bool {
    let found = await Purchase.restore()
    setPurchased(found)
    return found
  }

  /// The whole log, oldest first, not the 200 lines Settings keeps.
  func trialSummaryLog() -> [Transition] {
    TransitionLog().read().reversed()
  }

  /// "Night 5 of 7 free." during the trial; nil once purchased or over (D33).
  func trialNight(now: Date) -> Int? {
    guard !state.trial.purchased, let start = state.trial.start else { return nil }
    return Trial.night(
      since: start, now: now, sleep: state.sleepBlock?.schedule, calendar: .current, config: config)
  }
}
