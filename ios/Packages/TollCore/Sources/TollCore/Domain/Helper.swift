import Foundation

/// Before bed's three small helpers, offered in the gap between the lock and bed (D80). Each ends
/// with putting the phone down; none is a task, and none is ever counted or shown back.
public enum Helper: String, Codable, Hashable, Sendable, CaseIterable {
  /// Tomorrow's list, on paper: one text sheet, nothing typed.
  case list
  /// A soft tone to breathe with, screen off.
  case breathe
  /// A word game to play in bed with the eyes closed.
  case words

  /// The log line a helper leaves, so the night record can say one was used (D62).
  public var cause: ReconcileCause {
    switch self {
    case .list: .helperList
    case .breathe: .helperBreathe
    case .words: .helperWords
    }
  }
}

extension ReconcileCause {
  /// The helper a log line says was opened, if any.
  public var helper: Helper? {
    switch self {
    case .helperList: .list
    case .helperBreathe: .breathe
    case .helperWords: .words
    default: nil
    }
  }
}

/// Settings › Before bed's part for the helpers (D80): on by default, and the breath's length.
public struct Helpers: Codable, Hashable, Sendable {
  public var on = true
  /// Nil until the person moves it: the config's length.
  public var breathMinutes: Int?

  public init(on: Bool = true, breathMinutes: Int? = nil) {
    self.on = on
    self.breathMinutes = breathMinutes
  }

  public func breath(_ config: TollConfig) -> Int {
    let range = config.helpers.breathRange
    return min(
      max(breathMinutes ?? config.helpers.breathMinutes, range.lowerBound), range.upperBound)
  }
}

/// The breathing tone's shape over time, pure so it can be tested (D80): the pitch rises through
/// each in-breath and falls through each out-breath, eased at both ends so the turns are soft; the
/// loudness swells a little with it, comes in at the start and fades away over the last seconds.
public struct Breath: Equatable, Sendable {
  public var inhale: Double
  public var exhale: Double
  /// Seconds the tone plays, the fade included.
  public var length: Double
  public var fadeIn: Double
  public var fadeOut: Double
  public var swell: Double

  public init(minutes: Int, config: TollConfig = .defaults) {
    let helpers = config.helpers
    inhale = helpers.inhaleSeconds
    exhale = helpers.exhaleSeconds
    length = Double(minutes) * 60
    fadeIn = helpers.fadeInSeconds
    fadeOut = helpers.fadeOutSeconds
    swell = helpers.swell
  }

  public var cycle: Double { inhale + exhale }
  public var perMinute: Double { 60 / cycle }

  /// 0 at the bottom of a breath, 1 at the top.
  public func pitch(at seconds: Double) -> Double {
    let t = seconds.truncatingRemainder(dividingBy: cycle)
    if t < inhale { return (1 - cos(.pi * t / inhale)) / 2 }
    return (1 + cos(.pi * (t - inhale) / exhale)) / 2
  }

  /// 0 to 1 of the tone's loudness: 0 before it starts and once it has ended.
  public func gain(at seconds: Double) -> Double {
    guard seconds >= 0, seconds < length else { return 0 }
    let coming = fadeIn > 0 ? min(1, seconds / fadeIn) : 1
    let going = fadeOut > 0 ? min(1, (length - seconds) / fadeOut) : 1
    let breathing = (1 - swell) + swell * pitch(at: seconds)
    return breathing * coming * going
  }
}
