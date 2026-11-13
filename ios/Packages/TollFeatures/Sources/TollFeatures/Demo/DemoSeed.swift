#if DEBUG
  import Foundation
  import TollCore
  import TollData

  /// Seeds the in-memory store for a demo scenario: two blocks, three weeks of gate history shaped like
  /// the App Review account's (api/scripts/seed-review.mjs), and a fresh shield hit for the gate.
  struct DemoSeed: Sendable {
    let deps: Dependencies

    func run(_ launch: DemoLaunch) async {
      let scenario = launch.scenario
      // The simulator Keychain outlives a reinstall, so every scenario sets the session it needs.
      deps.keychain.set(scenario.signedIn ? launch.token : nil, for: .sessionToken)
      let store = deps.store
      if scenario.choseSolo { try? await store.setSetting("choseSolo", true) }
      if scenario.signedIn {
        try? await store.setSetting("friendsStepShown", true)
        try? await store.setSetting("isReturning", false)
      }
      guard scenario.hasBlocks else { return }
      let now = deps.clock.now
      let zone = deps.clock.timeZone
      let start = now.addingTimeInterval(-21 * 86_400)
      for block in Self.blocks(createdAt: start) {
        try? await store.registerApps(block.appRefs, kinds: [:])
        try? await store.save(block)
      }
      for (ref, tag) in Self.tags { try? await store.setTag(tag, for: ref) }
      // The gate finds a hit's block in the shared gate state, which only this fills.
      await deps.blocks.applyBlocks()
      var history = DemoHistory(timeZone: zone)
      try? await store.record(history.events(from: start, to: now))
      if scenario == .gate {
        Spool().append(
          SpoolRecord(
            kind: .blockHit, at: now, tzOffsetMinutes: GateEvent.offsetMinutes(at: now, in: zone),
            appRef: "a1", via: .open))
      }
    }

    static let tags: [(AppRef, Tag)] = [
      ("a1", .instagram), ("a2", .tiktok), ("a3", .youtube), ("a4", .reddit),
    ]

    static func blocks(createdAt: Date) -> [StoredBlock] {
      [
        StoredBlock(
          id: "b1", name: "Socials", schedule: .always, appRefs: ["a1", "a2", "a5"],
          createdAt: createdAt),
        StoredBlock(
          id: "b2", name: "Nights", schedule: .preset(.nights), appRefs: ["a3", "a4"],
          createdAt: createdAt.addingTimeInterval(60)),
      ]
    }
  }

  /// Deterministic gate history: the same seed draws the same days, so two renders of one commit match.
  struct DemoHistory {
    let timeZone: TimeZone
    let gate = TollConfig.Gate()
    /// TikTok twice: one app drawing most hits is what the Insights cards are about.
    static let refs: [AppRef] = ["a1", "a2", "a2", "a3", "a4", "a5"]
    static let nightRefs: Set<AppRef> = ["a3", "a4"]
    private var seed: UInt64 = 20_261_109

    init(timeZone: TimeZone) {
      self.timeZone = timeZone
    }

    mutating func events(from start: Date, to end: Date) -> [GateEvent] {
      var events: [GateEvent] = []
      var day = start
      while day < end {
        var free = gate.freePassesPerDay
        var waited = 0
        let hits = 2 + Int(next() * 6)
        let times = (0..<hits).map { _ in day.addingTimeInterval((7 + next() * 16) * 3_600) }
          .sorted()
        for at in times where at < end {
          let ref = Self.refs[Int(next() * Double(Self.refs.count))]
          if next() < 0.3 {
            events.append(event(.blockHit, at, ref, via: .dismiss))
          } else if free > 0 {
            free -= 1
            events.append(event(.blockHit, at, ref, via: .open))
            events.append(event(.pass, at + 20, ref, free: true, session: gate.sessionMinutes[1]))
          } else {
            let wait = gate.waits[min(waited, gate.waits.count - 1)]
            events.append(event(.blockHit, at, ref, via: .open))
            events.append(event(.waitStarted, at + 15, ref, wait: wait))
            if next() < 0.15 {
              events.append(event(.waitAbandoned, at + 75, ref))
            } else {
              waited += 1
              let done = at + 15 + TimeInterval(wait * 60)
              events.append(event(.waitCompleted, done, ref))
              events.append(
                event(
                  .pass, done + 1, ref, free: false, wait: wait, session: gate.sessionMinutes[0]))
            }
          }
        }
        day = day.addingTimeInterval(86_400)
      }
      return events
    }

    private func event(
      _ kind: GateEvent.Kind, _ at: Date, _ ref: AppRef, via: GateEvent.Via? = nil,
      free: Bool? = nil,
      wait: Int? = nil, session: Int? = nil
    ) -> GateEvent {
      GateEvent(
        kind: kind, occurredAt: at, tzOffsetMinutes: GateEvent.offsetMinutes(at: at, in: timeZone),
        appRef: ref,
        blockRef: BlockRef(rawValue: Self.nightRefs.contains(ref) ? "b2" : "b1"), via: via,
        free: free,
        waitMinutes: wait,
        sessionMinutes: session)
    }

    /// SplitMix64, mapped to [0, 1).
    private mutating func next() -> Double {
      seed &+= 0x9E37_79B9_7F4A_7C15
      var z = seed
      z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
      z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
      return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
  }
#endif
