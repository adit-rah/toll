import Foundation
import TollCore

/// The outbox (E2.15): events and other writes recorded locally are sent when there is an account.
/// Triggers: foreground, any pass, every `sync.flushIntervalSeconds`, background refresh, silent push.
/// Solo mode never calls this with a session, so solo never touches the network (spec §13).
public actor SyncEngine {
  let store: LocalStore
  let api: APIClient
  let keychain: Keychain
  private var failures = 0
  private var nextAttempt = Date.distantPast
  private var running = false

  public init(store: LocalStore, api: APIClient, keychain: Keychain) {
    self.store = store
    self.api = api
    self.keychain = keychain
  }

  public var isSignedIn: Bool { keychain.string(.sessionToken) != nil }

  /// Returns whether everything pending was sent.
  @discardableResult
  public func flush(now: Date = Date(), force: Bool = false) async -> Bool {
    guard isSignedIn, !running, force || now >= nextAttempt else { return false }
    running = true
    defer { running = false }
    do {
      try await sendEvents(now: now)
      try await sendWrites()
      failures = 0
      nextAttempt = .distantPast
      return true
    } catch let error as APIError where error.isUnauthorized {
      Log.sync.error("flush unauthorized; session ended")
      return false
    } catch {
      failures += 1
      let delay = OutboxPlan.backoff(afterFailures: failures, jitter: Double.random(in: 0...0.25))
      nextAttempt = now.addingTimeInterval(delay)
      Log.sync.error("flush failed (\(self.failures)); retry in \(Int(delay)) s")
      return false
    }
  }

  private func sendEvents(now: Date) async throws {
    let deviceId = keychain.deviceId()
    while true {
      let pending = try await store.pendingUpload(limit: OutboxPlan.batchLimit * 5)
      let batches = OutboxPlan.batches(pending)
      guard !batches.isEmpty else { return }
      for batch in batches {
        let body = EventBatch(deviceId: deviceId, events: batch.map(EventWire.init))
        let result: EventBatchResult = try await api.send(
          "POST", "events", json: body,
          idempotencyKey: batch.first?.id.lowercasedString ?? UUID.v7Key())
        let settled = OutboxPlan.settled(
          accepted: result.accepted, rejected: result.rejected.map { ($0.id, $0.reason) })
        try await store.markUploaded(settled, at: now)
      }
    }
  }

  private func sendWrites() async throws {
    for write in try await store.pendingWrites() {
      do {
        _ = try await api.send(
          write.method, write.path, query: [:], body: write.body,
          contentType: write.body == nil ? nil : "application/json",
          idempotencyKey: write.idempotencyKey)
      } catch let error as APIError
        where (400..<500).contains(error.status) && !error.isUnauthorized
      {
        Log.sync.error(
          "dropping write \(write.path, privacy: .public): \(error.code, privacy: .public)")
      }
      if let id = write.id { try await store.removeWrite(id) }
    }
  }

  /// Queues a write to send with the next flush; harmless in solo mode (it is cleared on sign-in).
  public func enqueue<B: Encodable & Sendable>(
    _ method: String, _ path: String, json body: B?, now: Date = Date()
  )
    async
  {
    let data = body.flatMap { try? JSONEncoder().encode($0) }
    try? await store.enqueueWrite(method: method, path: path, body: data, now: now)
  }

  /// Signing in after solo use uploads history through the history endpoint, which accepts old events.
  public func uploadHistory() async throws {
    let deviceId = keychain.deviceId()
    for batch in OutboxPlan.batches(try await store.allEvents()) {
      let body = EventBatch(deviceId: deviceId, events: batch.map(EventWire.init))
      let result: EventBatchResult = try await api.send("POST", "events/history", json: body)
      try await store.markUploaded(
        OutboxPlan.settled(
          accepted: result.accepted, rejected: result.rejected.map { ($0.id, $0.reason) }),
        at: Date())
    }
  }
}
