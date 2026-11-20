extension SleepModel {
  /// Tonight's start for someone who opted in: Thompson sampling with a floor (model spec, section 3).
  ///
  /// The chance each allowed start wins is estimated from `probDraws` draws of w ~ N(μ, Σ), then mixed
  /// with a uniform choice so every allowed start keeps at least `minProb`. One more uniform picks the
  /// start, so `prob` is exactly the chance it had; log it, or later evaluation is impossible. Every
  /// call takes the same draws whatever is allowed, keeping the stream in step with the reference.
  public func chooseOffset(_ context: NightContext, rng: inout SeededRNG) -> (
    offset: Int, prob: Double
  ) {
    let actions = artifact.actions
    var allowed = actions.map { context.allowedOffsets?.contains($0) ?? true }
    if !allowed.contains(true) { allowed = actions.map { $0 == 0 } }
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
    let mixed = actions.indices.map { k -> Double in
      guard allowed[k] else { return 0 }
      if count == 1 { return 1 }
      let p = Double(wins[k]) / Double(draws)
      return (1.0 - count * floor) * p + floor
    }
    let u = rng.uniform()
    var cumulative = 0.0
    for k in actions.indices {
      cumulative = cumulative + mixed[k]
      if allowed[k], u < cumulative { return (actions[k], mixed[k]) }
    }
    let last = allowed.lastIndex(of: true) ?? 0
    return (actions[last], mixed[last])
  }
}
