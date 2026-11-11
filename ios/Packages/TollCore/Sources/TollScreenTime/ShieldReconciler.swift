#if os(iOS)
  import Foundation
  @preconcurrency import ManagedSettings
  import OSLog
  import TollCore

  /// Brings the shield in line with blocks, schedules and sessions. The app runs it on launch and
  /// foreground; the monitor runs it on every callback. Whoever runs next corrects a missed callback.
  public struct ShieldReconciler: Sendable {
    public let gateStore: SharedGateStore
    public let registry: TokenRegistry
    public let spool: Spool
    private let log = Logger(subsystem: "com.advan.toll", category: "shield")

    public init(
      gateStore: SharedGateStore = SharedGateStore(), registry: TokenRegistry = TokenRegistry(),
      spool: Spool = Spool()
    ) {
      self.gateStore = gateStore
      self.registry = registry
      self.spool = spool
    }

    /// Ends sessions past their expiry (G-6), applies the plan, and returns the sessions it ended so the
    /// caller can record `session_ended`.
    @discardableResult
    public func reconcile(now: Date, timeZone: TimeZone, source: String) -> [ActiveSession] {
      var ended: [ActiveSession] = []
      let state = gateStore.update { state in
        ended = state.sessions.filter { $0.isExpired(at: now) }
        state.sessions.removeAll { $0.isExpired(at: now) }
      }
      let math = DayMath(timeZone: timeZone, resetHour: state.resetHour)
      let plan = ShieldPlan.make(
        blocks: state.blocks, sessions: state.sessions, at: now, math: math)
      apply(plan)
      if !ended.isEmpty { ActivityScheduler().stop(sessions: ended) }
      // D4: log every re-shield source for the first month.
      log.info(
        "reconcile source=\(source, privacy: .public) shielded=\(plan.shielded.count) ended=\(ended.count)"
      )
      return ended
    }

    public func apply(_ plan: ShieldPlan) {
      let store = ManagedSettingsStore(named: .blocks)
      let shielded = registry.tokens(for: plan.shielded)
      let unlocked = registry.tokens(for: plan.unlocked)
      store.shield.applications = shielded.applications.isEmpty ? nil : shielded.applications
      store.shield.webDomains = shielded.webDomains.isEmpty ? nil : shielded.webDomains
      store.shield.applicationCategories =
        shielded.categories.isEmpty
        ? nil : .specific(shielded.categories, except: unlocked.applications)
      store.shield.webDomainCategories =
        shielded.categories.isEmpty
        ? nil : .specific(shielded.categories, except: unlocked.webDomains)
    }

    public func clearAll() {
      ManagedSettingsStore(named: .blocks).clearAllSettings()
    }
  }
#endif
