import Foundation
import Observation
import TollCore
import TollData
import TollUI

/// The wait card and the session picker it turns into (E1.13, design §3.7–3.9, §4.10).
@MainActor
@Observable
public final class GateModel {
  public enum Phase: Equatable {
    case hidden
    /// The card's clock counts down to `until` by itself; the model republishes it only if it moves.
    case waiting(until: Date)
    case choosing
  }

  let app: AppModel
  public private(set) var phase: Phase = .hidden
  /// The app the card asks the user to name. Stays set once a tag is chosen so the naming section can
  /// finish its own collapse; cleared when the next wait starts.
  public private(set) var untaggedApp: AppRef?
  public private(set) var chosenTag: Tag?
  public var selectedMinutes: Int
  private var ticker: Task<Void, Never>?
  private var namingCheckedFor: UUID?
  private var gateDisagreed = false

  public init(app: AppModel) {
    self.app = app
    selectedMinutes = app.gate.lastSessionMinutes ?? app.config.gate.sessionMinutes.first ?? 5
  }

  var config: TollConfig.Gate { app.config.gate }
  public var sessionChoices: [Int] { config.sessionMinutes }
  public var primaryApp: AppRef? { app.gate.wait?.primaryApp ?? app.gate.pendingPass?.appRefs.first }

  /// "Wait 3 of today · next wait 8 min".
  public var waitLine: String? {
    guard let wait = app.gate.wait else { return nil }
    return Copy.Wait.line(
      number: wait.number, nextMinutes: GateRules.nextWaitMinutes(forWaitNumber: wait.number, config: config))
  }

  /// Recomputes the phase from shared state; the ticker runs only while a wait is shown.
  public func sync() async {
    if let wait = app.gate.wait {
      // Looked up before the card shows so it arrives with its naming section, not growing one.
      await checkNaming(for: wait)
      guard let current = app.gate.wait, current.id == wait.id else { return }
      showWait(current)
      startTicking()
    } else if app.gate.pendingPass != nil {
      if phase != .choosing {
        if case .waiting = phase { Haptics.light() }
        // Only on arrival: a later sync must not undo the length the user has just picked.
        if let last = app.gate.lastSessionMinutes, last != selectedMinutes { selectedMinutes = last }
        phase = .choosing
      }
      stopTicking()
    } else {
      // Observation notifies on every assignment, equal or not, and each one redraws the layer.
      if phase != .hidden { phase = .hidden }
      stopTicking()
    }
  }

  private func remaining(of wait: Wait) -> TimeInterval {
    wait.remaining(
      now: app.deps.clock.now, monotonic: app.deps.clock.monotonic,
      tolerance: TimeInterval(config.clockSkewToleranceSeconds))
  }

  private func showWait(_ wait: Wait) {
    let end = Date.now.addingTimeInterval(remaining(of: wait))
    // Recomputed on every check and never identical to the millisecond; only a real move (the
    // clock was changed, G-9) is worth redrawing the card for.
    if case .waiting(let shown) = phase, abs(shown.timeIntervalSince(end)) < 0.5 { return }
    phase = .waiting(until: end)
  }

  /// One store read per wait, not one per tick.
  private func checkNaming(for wait: Wait) async {
    guard namingCheckedFor != wait.id else { return }
    namingCheckedFor = wait.id
    if untaggedApp != nil { untaggedApp = nil }
    if chosenTag != nil { chosenTag = nil }
    guard let ref = wait.primaryApp else { return }
    // Its own task: `sync` runs inside the layer's `.task(id:)`, and a read cancelled along with
    // that would look the same as an app with no tag.
    let store = app.deps.store
    let lookup = Task { try await store.tag(for: ref) }
    do {
      let tag = try await lookup.value
      guard tag == nil, app.gate.wait?.id == wait.id else { return }
      untaggedApp = ref
    } catch {
      if namingCheckedFor == wait.id { namingCheckedFor = nil }
    }
  }

  private func startTicking() {
    guard ticker == nil else { return }
    gateDisagreed = false
    Haptics.light()
    ticker = Task { [weak self] in
      while !Task.isCancelled {
        let pause = self?.secondsToNextCheck ?? 1
        try? await Task.sleep(for: .seconds(pause))
        guard !Task.isCancelled, let self else { return }
        await self.check()
      }
    }
  }

  /// A second at most, so a changed clock is noticed; less at the end, so the picker arrives as the
  /// numeral reaches zero instead of up to a second after.
  private var secondsToNextCheck: TimeInterval {
    guard !gateDisagreed, let wait = app.gate.wait else { return 1 }
    return min(1, max(0.05, remaining(of: wait)))
  }

  /// The gate itself is asked only once the wait reads as over: every `GateService.tick` is a
  /// coordinated pass over the shared state file, and until then it has nothing to turn into a pass
  /// (G-4). The test is the gate's own, `Wait.isComplete`, on the same clock.
  private func check() async {
    guard let wait = app.gate.wait else {
      await sync()
      return
    }
    let done = wait.isComplete(
      now: app.deps.clock.now, monotonic: app.deps.clock.monotonic,
      tolerance: TimeInterval(config.clockSkewToleranceSeconds))
    if done {
      app.setGate(await app.deps.gate.tick())
      // If the gate's own clock is not there yet, ask again in a second rather than in a spin.
      gateDisagreed = app.gate.wait != nil
      await sync()
    } else {
      showWait(wait)
    }
  }

  private func stopTicking() {
    ticker?.cancel()
    ticker = nil
  }

  public func cancel() async {
    app.setGate(await app.deps.gate.cancelWait())
    await sync()
  }

  /// The chip fills at once; the store and the server follow.
  public func name(_ tag: Tag) {
    guard let ref = untaggedApp, chosenTag == nil else { return }
    chosenTag = tag
    Haptics.selection()
    Task { [app] in try? await app.deps.blocks.setTag(tag, for: ref) }
  }

  /// Unlocks the apps and leaves Toll for the app (G-6). The card drops as the system switches apps.
  public func open() async {
    _ = await app.deps.gate.startSession(minutes: selectedMinutes)
    app.setGate(await app.deps.gate.state)
    await sync()
  }
}
