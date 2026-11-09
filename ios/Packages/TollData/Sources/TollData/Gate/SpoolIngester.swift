import Foundation
import TollCore

#if os(iOS)
  import TollScreenTime
#endif

/// Moves extension spool lines into the event log (spec §11.1 "App launch and foreground: ingest the
/// spool"). Returns the newest "Open Toll" hit so the caller can decide whether to enter the gate.
public struct SpoolIngester: Sendable {
  public struct Result: Sendable {
    public var events: [GateEvent]
    public var latestOpenHit: GateEvent?
  }

  let spool: Spool
  let store: LocalStore

  public init(spool: Spool = Spool(), store: LocalStore) {
    self.spool = spool
    self.store = store
  }

  public func ingest() async -> Result {
    let parsed = spool.drain()
    if parsed.skipped > 0 { Log.gate.error("spool skipped \(parsed.skipped) unreadable lines") }
    var events: [GateEvent] = []
    var newRefs: [AppRef: TokenKind] = [:]
    for record in parsed.records {
      var ref = record.appRef
      if ref == nil, let token = record.token, let kind = record.tokenKind {
        ref = resolve(token: token, kind: kind)
        if let ref { newRefs[ref] = kind }
      }
      events.append(event(from: record, appRef: ref))
    }
    if !newRefs.isEmpty { try? await store.registerApps(Array(newRefs.keys), kinds: newRefs) }
    try? await store.record(events)
    let latest = events.filter { $0.kind == .blockHit && $0.via == .open }.max {
      $0.occurredAt < $1.occurredAt
    }
    return Result(events: events, latestOpenHit: latest)
  }

  private func resolve(token: Data, kind: TokenKind) -> AppRef? {
    #if os(iOS)
      return TokenRegistry().register(encoded: token, kind: kind)
    #else
      return nil
    #endif
  }

  private func event(from record: SpoolRecord, appRef: AppRef?) -> GateEvent {
    let kind: GateEvent.Kind =
      switch record.kind {
      case .blockHit: .blockHit
      case .checkin: .checkin
      case .sessionEnded: .sessionEnded
      }
    return GateEvent(
      id: record.id, kind: kind, occurredAt: record.at, tzOffsetMinutes: record.tzOffsetMinutes,
      appRef: appRef,
      appRefs: record.appRefs, via: record.via, sessionMinutes: record.sessionMinutes)
  }
}
