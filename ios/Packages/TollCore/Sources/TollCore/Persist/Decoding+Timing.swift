import Foundation

// Personal timing decodes lossily like everything stored (`Decoding.swift`). A hold that can't be
// read is dropped alone, and its entry reads as none: the lock goes back to the plan, never to a
// start nobody chose.

extension Timing {
  enum CodingKeys: String, CodingKey { case on, history, generator }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init()
    on = c.lossy(.on, or: false)
    history = c.lossyArray(.history)
    generator = c.lossy(.generator)
  }
}

extension Timing.Entry {
  enum CodingKeys: String, CodingKey { case night, hold }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(night: try c.decode(Date.self, forKey: .night), hold: c.lossy(.hold))
  }
}

extension Timing.Hold {
  enum CodingKeys: String, CodingKey { case start, offset, prob, settled }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      start: try c.decode(String.self, forKey: .start),
      offset: try c.decode(Int.self, forKey: .offset),
      prob: try c.decode(Double.self, forKey: .prob),
      settled: c.lossy(.settled, or: false))
  }
}
