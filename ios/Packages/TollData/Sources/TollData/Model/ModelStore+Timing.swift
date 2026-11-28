import Foundation
import SleepModel
import TollCore

extension ModelStore {
  /// Personal timing's start for the night TollCore asks about (D66, D99): the person's model as
  /// the night log has it, drawing with the kept generator, or a fresh seed before the first draw.
  /// The model keeps the latest hold, from the state or the night log, while the night is in its
  /// week and the start allowed, so a rebuild never moves a week's start. Nil if the model state
  /// can't be had.
  public func choose(_ ask: TimingRules.Ask) -> Command? {
    guard let cache = refresh() else { return nil }
    let model = SleepModel(artifact: ModelArtifact.bundled(), state: cache.state)
    let logged = Hold.latest(in: ModelCache.current(nights.lines()))
    let kept = ask.held.map {
      Hold(start: $0.start, offset: $0.offset, prob: $0.prob, settled: $0.settled)
    }
    let held = [kept, logged].compactMap { $0 }.max { $0.start < $1.start }
    var rng = SeededRNG(seed: ask.generator ?? UInt64.random(in: .min ... .max))
    let hold = model.chooseStart(
      night: ask.night, NightContext(weekend: ask.weekend, allowedOffsets: ask.allowed),
      held: held, rng: &rng)
    return .hold(
      Timing.Hold(
        start: hold.start, offset: hold.offset, prob: hold.prob, settled: hold.settled),
      generator: rng.state)
  }
}
