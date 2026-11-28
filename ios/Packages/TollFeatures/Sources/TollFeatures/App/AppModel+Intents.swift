import Foundation
import TollCore
import TollData
import TollScreenTime

/// What screens ask for. Each is one command, or a few, through `send`.
extension AppModel {
  /// The time screens read. Demo launches pin it (docs/renders.md), so a render shows the state its
  /// fixture built, whatever the runner's clock says.
  var now: Date {
    #if DEBUG
      if let demo = DemoScenario.current { return DemoClock.now(for: demo) }
    #endif
    return Date()
  }

  // MARK: Setup and blocks

  func finishSetup(sleep: Block, home: Place?, fit: Fit? = nil) {
    let trialStart = TrialClock().begin(now: Date())
    send(
      .edit,
      [.finishSetup(sleep: Blocklist.counted(sleep), home: home, trialStart: trialStart, fit: fit)])
  }

  /// Sleep and both buffers, from the one-time flow or Settings › Sleep (#144). Held while the
  /// night is on (B-3).
  @discardableResult
  func fit(_ fit: Fit) -> CommandError? {
    send(.edit, [.fit(fit)])
  }

  /// One side's buffer from Settings › Sleep: growing toward a target, or fixed.
  func setBuffer(_ side: Gap.Side, _ setting: Gap.Setting, target: Int?) {
    send(.edit, [.buffer(side, setting, target: target)])
  }

  /// How a one-time flow went (`Flows`): shown, answered with the person's commands (their fit,
  /// personal timing on), or not now.
  func flow(_ id: String, _ outcome: FlowRecord.Outcome, commands: [Command] = []) {
    guard let flow = Flows.registry.first(where: { $0.id == id }) else { return }
    send(.edit, commands + [.flow(id: id, version: flow.version, outcome)])
    if outcome != .shown { dueFlow = nil }
  }

  /// "Only when I'm home" (D68): Home saved and the night waiting for it, held while a night is on.
  func setHome(_ home: Place) {
    send(.edit, [.setHome(home)])
  }

  /// The way back: the night runs on its hours wherever the phone is; home stays saved.
  func useAnywhere() {
    send(.edit, [.useAnywhere])
  }

  /// A Tonight card put away for good (#102).
  func dismiss(_ card: TonightCard) {
    send(.edit, [.dismissCard(card)])
  }

  /// Last night's card put away for this morning; the strip still opens it.
  func putAwayLastNight(_ night: Date) {
    send(.edit, [.putAwayLastNight(night)])
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

  // MARK: Pause (the spec's door, D67)

  /// Opens the pause sheet: "Open Dusk to pause" was tapped on the block screen in the last two minutes,
  /// or a pause is under way.
  var showsDoor: Bool {
    guard state.isBlocking else { return false }
    if state.door != nil { return true }
    guard let asked = state.doorAskedAt else { return false }
    return Date().timeIntervalSince(asked) < 120
  }

  /// Keeps an open sheet up: someone deciding for more than two minutes doesn't lose it (#47). It
  /// ends when the ask is answered or dismissed, the pause ends, or the block does.
  var doorPending: Bool {
    state.isBlocking && (state.door != nil || state.doorAskedAt != nil)
  }

  /// "Pause": the wait starts. Every block's shield lifts when it ends (D67).
  func startDoor() { send(.doorChosen, [.startDoor]) }

  func cancelDoor() { send(.doorCancelled, [.cancelDoor]) }
  func lockDoor() { send(.doorLocked, [.lockDoor]) }
  func dismissDoor() { send(.foreground, [.askDoor(nil)]) }

  /// Tonight's "Pause": the same sheet the block screen opens.
  func askDoor() { send(.foreground, [.askDoor(Date())]) }

  // MARK: Permissions

  /// Asks again; iOS may not show the prompt after a denial, so Settings opens then (#45).
  func turnOnScreenTime() async {
    await requestScreenTime()
    if screenTime != .approved { openSystemSettings() }
  }

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

  /// "Night 5 of 14 free." during the trial; nil once purchased or over (D33).
  func trialNight(now: Date) -> Int? {
    guard !state.trial.purchased, let start = state.trial.start else { return nil }
    return Trial.night(
      since: start, now: now, sleep: state.sleepBlock?.schedule, calendar: .current, config: config)
  }
}
