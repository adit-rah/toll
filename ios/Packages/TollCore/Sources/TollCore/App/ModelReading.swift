import Foundation

/// What the person's sleep model says, as the app reads it (TollData's `ModelStore`) and hands it
/// over: plain numbers, so the rules and the words that use them never link the model (#189).
public struct ModelReading: Equatable, Sendable {
  /// The one thing the model may tell someone (D66): what starting the lock earlier did to when
  /// they fell asleep. Only the start was randomized, so only this may be said with "because".
  public struct Insight: Equatable, Sendable {
    /// Minutes sooner asleep with the lock `earlier` minutes before the person's own start;
    /// negative is later.
    public var minutes: Double
    /// The range the model shows (90%), in the same sense. It never crosses zero: the zero test
    /// that lets the insight show is stricter.
    public var low: Double
    public var high: Double
    /// The usable nights it rests on.
    public var nights: Int
    /// How much earlier the compared start is (`start_30_earlier`).
    public var earlier: Int

    public init(minutes: Double, low: Double, high: Double, nights: Int, earlier: Int = 30) {
      self.minutes = minutes
      self.low = low
      self.high = high
      self.nights = nights
      self.earlier = earlier
    }

    public var sooner: Bool { minutes > 0 }

    /// The side a settled start sits on (D66): earlier when an earlier start meant sooner asleep.
    func supports(_ offset: Int) -> Bool { sooner ? offset < 0 : offset > 0 }
  }

  /// Usable nights so far.
  public var nights: Int
  /// While the model shows one; never before 28 usable nights (D113).
  public var insight: Insight?

  public init(nights: Int, insight: Insight? = nil) {
    self.nights = nights
    self.insight = insight
  }
}

extension YourSleep {
  /// The insight on Your sleep (#189): how much sooner or later, the sentence that says why, and
  /// the range and nights it rests on. A fact, never a grade (D104).
  public struct Finding: Equatable, Sendable {
    public var sooner: Bool
    /// "Asleep 12 min sooner".
    public var value: String
    /// "You fell asleep sooner because apps locked 30 min earlier."
    public var line: String
    /// "Likely 5 to 19 min, from 34 nights".
    public var detail: String
    public var spoken: String

    init(_ insight: ModelReading.Insight) {
      sooner = insight.sooner
      // In the insight's own sense, so the range reads smaller end first either way.
      let sign = insight.sooner ? 1.0 : -1.0
      let minutes = Self.whole(insight.minutes * sign)
      let ends = [insight.low * sign, insight.high * sign].map(Self.whole).sorted()
      value = Copy.Timing.foundValue(minutes, sooner: sooner)
      line = Copy.Timing.foundLine(sooner: sooner, earlier: insight.earlier)
      detail = Copy.Timing.foundDetail(ends[0], ends[1], nights: insight.nights)
      spoken = Copy.Timing.foundSpoken(
        minutes, sooner: sooner, earlier: insight.earlier, low: ends[0], high: ends[1],
        nights: insight.nights)
    }

    /// Whole minutes, at least 1: the range never reaches zero, so "0" would say less than it is.
    static func whole(_ minutes: Double) -> Int { max(1, Int(minutes.rounded())) }
  }

  /// The insight when the model shows one; otherwise, with personal timing on, the line that says
  /// Dusk is still learning. Nothing for someone who never chose timing.
  static func finding(_ model: ModelReading?, timingOn: Bool) -> (Finding?, String?) {
    if let insight = model?.insight { return (Finding(insight), nil) }
    return (nil, timingOn ? Copy.Timing.learning(nights: model?.nights) : nil)
  }
}
