import Foundation

/// Which app refs must be shielded right now. Every writer of the shield (app, monitor) computes this
/// same plan, so a late or missing callback is corrected by whoever runs next (spec §6).
public struct ShieldPlan: Equatable, Sendable {
  public var shielded: Set<AppRef>
  /// Apps unlocked by a session. Needed as exceptions when a whole category is shielded.
  public var unlocked: Set<AppRef>

  public init(shielded: Set<AppRef>, unlocked: Set<AppRef>) {
    self.shielded = shielded
    self.unlocked = unlocked
  }

  public static func make(
    blocks: [BlockDefinition], sessions: [ActiveSession], at date: Date, math: DayMath,
    monotonic: MonotonicInstant? = nil, tolerance: TimeInterval = ActiveSession.defaultTolerance
  ) -> ShieldPlan {
    let live = sessions.filter {
      !$0.isExpired(at: date, monotonic: monotonic, tolerance: tolerance)
    }
    let unlocked = Set(live.flatMap(\.appRefs))
    let active = blocks.filter { $0.schedule.isActive(at: date, in: math) }
    return ShieldPlan(
      shielded: Set(active.flatMap(\.appRefs)).subtracting(unlocked), unlocked: unlocked)
  }
}

/// Picker limits (spec §6): the platform shields nothing above 50 tokens.
public enum BlockLimits {
  public static func canAddBlock(existing: Int, config: TollConfig.Blocks) -> Bool {
    existing < config.max
  }

  public static func fits(tokenCount: Int, otherBlocksTokenCount: Int, config: TollConfig.Blocks)
    -> Bool
  {
    tokenCount + otherBlocksTokenCount <= config.maxTokens
  }
}
