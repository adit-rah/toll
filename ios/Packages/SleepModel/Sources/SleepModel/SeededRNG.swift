import Foundation

/// SplitMix64, the same stream as `dusk_model/rng.py`. Swift's system generator can't be seeded, and a
/// test must be able to repeat a draw; the app stores `state` between nights.
public struct SeededRNG: RandomNumberGenerator, Sendable, Equatable {
  public var state: UInt64

  public init(seed: UInt64) { state = seed }

  public mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  /// In [0, 1): the top 53 bits.
  public mutating func uniform() -> Double {
    Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
  }

  /// Box–Muller, cosine branch only, so every normal takes exactly two uniforms.
  public mutating func normal() -> Double {
    let u1 = 1.0 - uniform()
    let u2 = uniform()
    return (-2.0 * log(u1)).squareRoot() * cos(6.283185307179586 * u2)
  }
}
