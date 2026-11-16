import Foundation
import os

/// iOS gives a launch in the background about 30 s (a silent push, a background refresh) and kills an
/// app that has not said it is done by then; the kill is reported as a crash. Toll's background work is
/// an outbox flush and a Home refresh, each several requests with a 20 s timeout, so on a slow network
/// it can run past that. The answer to iOS goes back by the budget whatever the work is doing. The work
/// itself is never cancelled: the spool is drained before its events are written, and a cancelled write
/// would lose them. Unfinished, it is suspended with the app and carries on at the next launch.
final class BackgroundWork: Sendable {
  static let budget: Duration = .seconds(25)

  private struct State: Sendable {
    var settled: Bool?
    var waiter: CheckedContinuation<Bool, Never>?
  }

  private let state = OSAllocatedUnfairLock(initialState: State())

  /// Starts `work` and returns when it finishes (true), or when `budget` passes or `stop()` is called
  /// (false), whichever is first.
  func run(
    within budget: Duration = BackgroundWork.budget,
    _ work: @escaping @MainActor @Sendable () async -> Void
  ) async -> Bool {
    let timer = Task { [self] in
      try? await Task.sleep(for: budget)
      settle(false)
    }
    Task { @MainActor [self] in
      await work()
      timer.cancel()
      settle(true)
    }
    return await withCheckedContinuation { continuation in
      let early = state.withLock { state -> Bool? in
        if let settled = state.settled { return settled }
        state.waiter = continuation
        return nil
      }
      if let early { continuation.resume(returning: early) }
    }
  }

  /// The system is taking the time back early (a refresh task's expiration): answer now.
  func stop() {
    settle(false)
  }

  private func settle(_ finished: Bool) {
    let waiter = state.withLock { state -> CheckedContinuation<Bool, Never>? in
      guard state.settled == nil else { return nil }
      state.settled = finished
      defer { state.waiter = nil }
      return state.waiter
    }
    waiter?.resume(returning: finished)
  }
}
