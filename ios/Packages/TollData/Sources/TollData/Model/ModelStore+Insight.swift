import Foundation
import SleepModel
import TollCore

extension ModelStore {
  /// What Your sleep and Tonight say about personal timing (#189), from `model.json` as it stands:
  /// cheap enough to read before the first frame, so Tonight's reason never changes under the eye.
  /// Nil without a cache, or with one an older artifact built, until `refresh` rebuilds it.
  public func reading() -> ModelReading? {
    guard let data = CoordinatedFile.read(url),
      let cache = try? JSONDecoder().decode(ModelCache.self, from: data)
    else { return nil }
    return Self.reading(of: cache)
  }

  /// The model's insight as plain numbers; the words are TollCore's.
  public static func reading(of cache: ModelCache) -> ModelReading? {
    let artifact = ModelArtifact.bundled()
    guard cache.artifact.version == artifact.version,
      cache.artifact.sha256 == (artifact.sha256 ?? "")
    else { return nil }
    let model = SleepModel(artifact: artifact, state: cache.state)
    let insight = model.insights().first { $0.kind == .start30Earlier }.map {
      ModelReading.Insight(minutes: $0.minutes, low: $0.low, high: $0.high, nights: $0.nights)
    }
    return ModelReading(nights: cache.state.nights, insight: insight)
  }
}
