import Foundation
import SleepModel
import TollCore

/// The person's sleep model state, `model.json` in the App Group (TollCore's `ModelFile`): brought up
/// to the night log each time Dusk opens, and rebuilt from every night when the bundled artifact
/// changes (#140, D52). Only the app writes it; the monitor reads which artifact it names, to stamp
/// the nights it records. Nothing in it leaves the phone.
public struct ModelStore: Sendable {
  public let url: URL
  let nights: NightLog

  public init(url: URL = ModelFile.url, nights: NightLog = NightLog()) {
    self.url = url
    self.nights = nights
  }

  /// What the app stamps its night records with: the artifact this build runs. No model chooses the
  /// start yet, so the policy is fixed.
  public static let stamp = ModelStamp.fixed(ModelArtifact.bundled().version)

  /// Folds in the nights recorded since, or rebuilds; written, atomically, only when it changed.
  /// A file that can't be read is a cache like any other: it's rebuilt.
  @discardableResult
  public func refresh() -> ModelCache? {
    let artifact = ModelArtifact.bundled()
    let records = ModelCache.current(nights.lines())
    var result: ModelCache?
    CoordinatedFile.change(url) { contents, writer in
      let held = contents.data.flatMap { try? JSONDecoder().decode(ModelCache.self, from: $0) }
      let next = ModelCache.refreshed(
        held, artifact: artifact, policy: Self.stamp.policy, records: records
      ).cache
      result = next
      let encoder = JSONEncoder()
      encoder.outputFormatting = .sortedKeys
      guard next != held, let data = try? encoder.encode(next) else { return }
      writer.replace(with: data)
    }
    return result
  }
}
