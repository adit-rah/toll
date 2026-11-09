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
    case waiting(remaining: TimeInterval)
    case choosing
  }

  let app: AppModel
  public private(set) var phase: Phase = .hidden
  public private(set) var untaggedApp: AppRef?
  public var selectedMinutes: Int
  private var ticker: Task<Void, Never>?

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

  /// Recomputes the phase from shared state; starts the one-second ticker only while a wait is shown.
  public func sync() async {
    let state = app.gate
    if let wait = state.wait {
      let remaining = wait.remaining(
        now: app.deps.clock.now, monotonic: app.deps.clock.monotonic,
        tolerance: TimeInterval(config.clockSkewToleranceSeconds))
      phase = .waiting(remaining: remaining)
      await refreshNaming(wait.primaryApp)
      startTicking()
    } else if state.pendingPass != nil {
      if case .waiting = phase { Haptics.light() }
      phase = .choosing
      selectedMinutes = state.lastSessionMinutes ?? selectedMinutes
      stopTicking()
    } else {
      phase = .hidden
      stopTicking()
    }
  }

  private func refreshNaming(_ ref: AppRef?) async {
    guard let ref else { return }
    let tag = try? await app.deps.store.tag(for: ref)
    untaggedApp = tag == nil ? ref : nil
  }

  private func startTicking() {
    guard ticker == nil else { return }
    Haptics.light()
    ticker = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        guard let self else { return }
        self.app.setGate(await self.app.deps.gate.tick())
        await self.sync()
      }
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

  public func name(_ tag: Tag) async {
    guard let ref = untaggedApp else { return }
    Haptics.selection()
    try? await app.deps.blocks.setTag(tag, for: ref)
    untaggedApp = nil
  }

  /// Unlocks the apps and leaves Toll for the app (G-6). The card drops as the system switches apps.
  public func open() async {
    _ = await app.deps.gate.startSession(minutes: selectedMinutes)
    app.setGate(await app.deps.gate.state)
    await sync()
  }
}
