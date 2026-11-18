import Foundation

extension Copy {
  public enum Trial {
    /// P-5: the only mention before the trial ends.
    public static func night(_ night: Int, of nights: Int) -> String {
      "Night \(night) of \(nights) free."
    }

    public static let endedTitle = "Seven nights."
    public static func nightsBlocked(_ n: Int) -> String {
      n == 1 ? "Blocked at home: 1 night" : "Blocked at home: \(n) nights"
    }
    public static func blockScreens(_ n: Int) -> String {
      n == 1 ? "Block screen came up: 1 time" : "Block screen came up: \(n) times"
    }
    public static func unlocksUsed(_ n: Int) -> String {
      n == 1 ? "Unlocks used: 1" : "Unlocks used: \(n)"
    }
    public static func keep(price: String) -> String { "Keep it — \(price) once" }
    public static let restore = "Restore purchase"
    public static let without = "Without it, nothing is blocked."
    public static let pending = "Waiting for approval."
    public static let failed = "The purchase did not go through."
    public static let nothingToRestore = "No purchase found for this Apple Account."
  }
}
