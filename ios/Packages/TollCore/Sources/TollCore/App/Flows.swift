import Foundation

/// Something a person already using Dusk must decide once, because a build changed what it keeps:
/// confirming a value the onboarding now asks for, say. There's no server, so the change can only
/// happen on the phone, with them. `docs/flows/README.md` says how one is added and charted.
public struct OneTimeFlow: Sendable, Identifiable {
  public var id: String
  /// Raised only when everyone who answered must be asked again.
  public var version: Int
  /// Whether this person needs it, from the state alone: set up before a build, no answer yet.
  public var applies: @Sendable (DuskState) -> Bool
  /// What the state becomes if it's put off for good, chosen so nothing changes for the person.
  public var defaults: @Sendable (DuskState) -> [Command]

  public init(
    id: String, version: Int, applies: @escaping @Sendable (DuskState) -> Bool,
    defaults: @escaping @Sendable (DuskState) -> [Command]
  ) {
    self.id = id
    self.version = version
    self.applies = applies
    self.defaults = defaults
  }
}

/// How a one-time flow last went, kept in the state so it asks once per version.
public struct FlowRecord: Codable, Hashable, Sendable {
  public enum Outcome: String, Codable, Hashable, Sendable {
    /// On screen and not answered yet: it comes back on a later day.
    case shown
    case answered
    case notNow
    /// Put off `flows.offers` times: its defaults applied.
    case defaulted
  }

  public var version: Int
  public var outcome: Outcome
  public var at: Date
  /// "Not now" at this version.
  public var notNow = 0

  public init(version: Int, outcome: Outcome, at: Date, notNow: Int = 0) {
    self.version = version
    self.outcome = outcome
    self.at = at
    self.notNow = notNow
  }

  public var done: Bool { outcome == .answered || outcome == .defaulted }
}

public enum Flows {
  /// Every flow this build can ask, in the order they'd show.
  public static let registry: [OneTimeFlow] = [fitSleep]

  /// #1, "Fit Dusk to your sleep" (#144): people set up before the buffers around sleep are asked
  /// for their sleep and both buffers once. Their night is as it was until they answer; put off
  /// for good, it stays so, with no buffer after.
  public static let fitSleep = OneTimeFlow(
    id: "fit-sleep", version: 1,
    applies: { $0.setupFinishedAt != nil && $0.after.offered },
    defaults: { _ in [.buffer(.after, .fixed(0), target: nil)] })

  /// The flow to show now, if any: the app asks at each foreground. At most one a day, and only at
  /// a calm moment.
  public static func due(
    _ state: DuskState, now: Date, calendar: Calendar, config: TollConfig = .defaults,
    registry: [OneTimeFlow] = registry
  ) -> OneTimeFlow? {
    guard calm(state, now: now, calendar: calendar, config: config) else { return nil }
    return registry.first { flow in
      guard flow.applies(state) else { return false }
      guard let record = state.flows[flow.id], record.version >= flow.version else { return true }
      return !record.done
    }
  }

  /// Never during a night (its gap included) or a pause, nor in the last minutes before the lock,
  /// nor before setup is done; and not twice on one day.
  public static func calm(
    _ state: DuskState, now: Date, calendar: Calendar, config: TollConfig = .defaults
  ) -> Bool {
    guard state.setupFinishedAt != nil, !state.isBlocking, state.door == nil,
      state.doorAskedAt == nil, let lock = state.lockSleep
    else { return false }
    if lock.schedule.occurrence(containing: now, calendar: calendar) != nil { return false }
    let quiet = TimeInterval(config.flows.quietBeforeLockMinutes * 60)
    if let next = lock.schedule.nextStart(after: now, calendar: calendar),
      next.timeIntervalSince(now) < quiet
    {
      return false
    }
    return !state.flows.values.contains { calendar.isDate($0.at, inSameDayAs: now) }
  }

  /// Records how a flow went; "Not now" on its last offer puts it off for good, and the commands
  /// returned apply its defaults.
  public static func record(
    _ id: String, version: Int, _ outcome: FlowRecord.Outcome, in state: inout DuskState,
    now: Date, config: TollConfig = .defaults, registry: [OneTimeFlow] = registry
  ) -> [Command] {
    let earlier = state.flows[id].flatMap { $0.version == version ? $0 : nil }
    var record = FlowRecord(
      version: version, outcome: outcome, at: now, notNow: earlier?.notNow ?? 0)
    var defaults: [Command] = []
    if outcome == .notNow {
      record.notNow += 1
      if record.notNow >= config.flows.offers {
        record.outcome = .defaulted
        defaults = registry.first { $0.id == id }?.defaults(state) ?? []
      }
    }
    state.flows[id] = record
    return defaults
  }
}

extension FlowRecord {
  enum CodingKeys: String, CodingKey { case version, outcome, at, notNow }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      version: c.lossy(.version, or: 0), outcome: c.lossy(.outcome, or: .answered),
      at: try c.decode(Date.self, forKey: .at), notNow: c.lossy(.notNow, or: 0))
  }
}

extension FlowRecord.Outcome {
  /// An outcome from a newer build counts as answered: never ask again because of an unknown word.
  public init(from decoder: Decoder) throws { self = try decoder.raw(or: .answered) }
}
