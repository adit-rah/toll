extension SleepModel {
  /// A start drawn by Thompson sampling with a floor (model spec, section 3), for one night: v0's
  /// policy. `chooseStart` holds a draw for a week (D66); both draw the same way.
  ///
  /// The chance each allowed start wins is estimated from `probDraws` draws of w ~ N(μ, Σ), then mixed
  /// with a uniform choice so every allowed start keeps at least `minProb`. One more uniform picks the
  /// start, so `prob` is exactly the chance it had; log it, or later evaluation is impossible. Every
  /// call takes the same draws whatever is allowed, keeping the stream in step with the reference.
  public func chooseOffset(_ context: NightContext, rng: inout SeededRNG) -> (
    offset: Int, prob: Double
  ) {
    let allowed = allowedStarts(context)
    let mixed = floored(context, allowed: allowed, rng: &rng)
    let k = Self.pick(mixed, allowed: allowed, u: rng.uniform())
    return (artifact.actions[k], mixed[k])
  }

  /// Which of the artifact's starts the person allows tonight; the plan alone if none.
  func allowedStarts(_ context: NightContext) -> [Bool] {
    let actions = artifact.actions
    let allowed = actions.map { context.allowedOffsets?.contains($0) ?? true }
    return allowed.contains(true) ? allowed : actions.map { $0 == 0 }
  }

  /// p' = (1 − K·floor)·p + floor over the K allowed starts, from `probDraws` posterior draws.
  func floored(_ context: NightContext, allowed: [Bool], rng: inout SeededRNG) -> [Double] {
    let actions = artifact.actions
    let phis = actions.map { Self.phi(offset: $0, context) }
    let bases = phis.map(base)
    let l = factor
    let mu = mean(l)
    let draws = artifact.policy.probDraws
    var wins = [Int](repeating: 0, count: actions.count)
    for _ in 0..<draws {
      let z = (0..<4).map { _ in rng.normal() }
      let x = Linear4.backward(l, z)
      let w = (0..<4).map { mu[$0] + x[$0] }
      var best = Double.infinity
      var pick = 0
      for k in actions.indices where allowed[k] {
        let pred = bases[k] + Linear4.dot(phis[k], w)
        if pred < best {
          best = pred
          pick = k
        }
      }
      wins[pick] += 1
    }
    let count = Double(allowed.filter { $0 }.count)
    let floor = artifact.policy.minProb
    return actions.indices.map { k -> Double in
      guard allowed[k] else { return 0 }
      if count == 1 { return 1 }
      let p = Double(wins[k]) / Double(draws)
      return (1.0 - count * floor) * p + floor
    }
  }

  /// The index `u` lands on; the last allowed start if rounding leaves none.
  static func pick(_ mixed: [Double], allowed: [Bool], u: Double) -> Int {
    var cumulative = 0.0
    for k in mixed.indices {
      cumulative = cumulative + mixed[k]
      if allowed[k], u < cumulative { return k }
    }
    return allowed.lastIndex(of: true) ?? 0
  }
}
