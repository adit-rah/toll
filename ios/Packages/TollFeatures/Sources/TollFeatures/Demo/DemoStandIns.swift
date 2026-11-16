#if DEBUG
  import Foundation
  import TollCore

  /// The things a simulator cannot have are a picker token and Screen Time usage. In a demo launch every block counts as
  /// complete, and an app shows its tag's name and a generic icon where a phone shows the system's own
  /// (docs/renders.md). Without this every render carries "Blocks need re-picking".
  enum DemoStandIns {
    static let active = UserDefaults.standard.string(forKey: "TollDemo") != nil
    /// The simulator has no Screen Time data, so the report extension draws nothing there.
    static let screenTime = Copy.duration(6_120)

    static func name(for ref: AppRef) -> String? {
      DemoSeed.tags.first { $0.0 == ref }.map { Copy.Tags.display($0.1) }
    }
  }
#endif
