import Foundation
import TollCore

#if os(iOS)
  import FamilyControls
  import TollScreenTime
#endif

/// Creating, editing and removing blocks (E5.31) and tagging apps (G-3a). Each change is an event, so
/// friends see removals and loosened schedules (N-5); the shield follows at once.
public actor BlockService {
  let store: LocalStore
  let sync: SyncEngine
  let gateStore: SharedGateStore
  let clock: any TollClock
  let analytics: Analytics

  public init(
    store: LocalStore, sync: SyncEngine, clock: any TollClock = SystemClock(),
    gateStore: SharedGateStore = SharedGateStore(), analytics: Analytics = .disabled
  ) {
    self.store = store
    self.sync = sync
    self.clock = clock
    self.gateStore = gateStore
    self.analytics = analytics
  }

  private func event(_ kind: GateEvent.Kind, block: StoredBlock, old: Schedule? = nil) -> GateEvent {
    let now = clock.now
    return GateEvent(
      kind: kind, occurredAt: now, tzOffsetMinutes: GateEvent.offsetMinutes(at: now, in: clock.timeZone),
      blockRef: block.id, appRefs: block.appRefs, schedule: block.schedule, oldSchedule: old)
  }

  /// Saves a new or edited block and records `block_added` or `block_changed`.
  public func save(_ block: StoredBlock, kinds: [AppRef: TokenKind]) async throws {
    let previous = try await store.blocks().first { $0.id == block.id }
    try await store.registerApps(block.appRefs, kinds: kinds)
    try await store.save(block)
    if let previous {
      if previous.schedule != block.schedule || previous.appRefs != block.appRefs {
        try await store.record([event(.blockChanged, block: block, old: previous.schedule)])
      }
    } else {
      try await store.record([event(.blockAdded, block: block)])
      analytics.send(.blockAdded)
    }
    await sync.enqueue("PUT", "blocks/\(block.id.rawValue)", json: BlockMetaBody(block))
    await applyBlocks()
    flushSoon(force: true)
  }

  /// Removal is always possible and always visible to friends (G-8, principle 6).
  public func remove(_ id: BlockRef) async throws {
    guard let block = try await store.blocks().first(where: { $0.id == id }) else { return }
    try await store.deleteBlock(id)
    try await store.record([event(.blockRemoved, block: block)])
    analytics.send(.blockRemoved)
    await applyBlocks()
    flushSoon(force: true)
  }

  public func setTag(_ tag: Tag, for ref: AppRef) async throws {
    try await store.setTag(tag, for: ref)
    await sync.enqueue("PUT", "apps/\(ref.rawValue)", json: ["tag": tag.rawValue])
    flushSoon(force: false)
  }

  /// The change is already saved and shielded on the phone; Done and the tag chips must not wait for the
  /// upload, which can take a full timeout with no signal.
  private func flushSoon(force: Bool) {
    Task { [sync] in await sync.flush(force: force) }
  }

  /// Pushes block definitions to the extensions, schedules their windows and applies the shield.
  public func applyBlocks() async {
    let blocks = (try? await store.blocks()) ?? []
    gateStore.update { $0.blocks = blocks.map(\.definition) }
    #if os(iOS)
      ActivityScheduler().schedule(blocks: blocks.map(\.definition))
      ActivityScheduler().scheduleCheckin()
      ShieldReconciler().reconcile(now: clock.now, timeZone: clock.timeZone, source: "blocks")
    #endif
  }

  /// Total tokens in all blocks except one, for the picker limit (spec §6, `blocks.maxTokens`).
  public func tokenCount(excluding id: BlockRef?) async -> Int {
    let blocks = (try? await store.blocks()) ?? []
    return blocks.filter { $0.id != id }.reduce(0) { $0 + $1.appRefs.count }
  }

  #if os(iOS)
    /// Turns a picker selection into app refs (creating refs for new tokens) and their kinds.
    public nonisolated func refs(for selection: FamilyActivitySelection) -> (
      refs: [AppRef], kinds: [AppRef: TokenKind]
    ) {
      let registry = TokenRegistry()
      let refs = registry.register(selection)
      var kinds: [AppRef: TokenKind] = [:]
      for ref in refs { kinds[ref] = registry.kind(of: ref) ?? .application }
      return (refs, kinds)
    }
  #endif
}

struct BlockMetaBody: Codable, Sendable {
  var schedule: Schedule
  var appRefs: [String]

  init(_ block: StoredBlock) {
    schedule = block.schedule
    appRefs = block.appRefs.map(\.rawValue)
  }
}
