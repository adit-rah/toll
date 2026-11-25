import Foundation

/// The trial's start, kept twice (P-4, D78): in this phone's Keychain, which outlives deleting the
/// app, and as an iCloud Keychain item, so a new or erased phone on the same Apple ID continues the
/// same free nights. The earliest wins, so neither copy can start them again. With iCloud Keychain
/// off the second copy never leaves the phone and agrees with the first.
///
/// Its format, seconds since 2001 as text, never changes (#140): an older build on another phone
/// of the same Apple ID reads the iCloud copy. Anything more goes in a new Keychain account beside
/// it. A copy this build can't read is never written over and never read as "no start".
public struct TrialStart: Equatable, Sendable {
  /// One copy as the Keychain gave it.
  public enum Reading: Equatable, Sendable {
    case none
    case date(Date)
    /// There, but not a start this build can read: corrupt, or a format it doesn't know. The most
    /// it can mean is a start no later than when it was written, so that's what it counts as:
    /// never new free nights.
    case unreadable(writtenAt: Date)
    /// The Keychain didn't say (locked, busy): there may be a start. Nothing is written while any
    /// copy is unknown, so an earlier start from another phone is never dropped.
    case unknown

    var date: Date? {
      switch self {
      case .none, .unknown: nil
      case .date(let date): date
      case .unreadable(let written): written
      }
    }
  }

  public var thisPhone: Reading
  public var appleID: Reading

  public init(thisPhone: Reading, appleID: Reading) {
    self.thisPhone = thisPhone
    self.appleID = appleID
  }

  public init(thisPhone: Date?, appleID: Date?) {
    self.init(
      thisPhone: thisPhone.map(Reading.date) ?? .none, appleID: appleID.map(Reading.date) ?? .none)
  }

  public var start: Date? { [thisPhone.date, appleID.date].compactMap(\.self).min() }

  /// Both copies hold the earliest start: a phone that began before D78 gets its iCloud copy, and
  /// one that began before the iCloud copy arrived takes the earlier date. An unreadable copy stays
  /// as it is.
  public var settled: TrialStart {
    guard let start, known else { return self }
    return TrialStart(
      thisPhone: Self.put(start, over: thisPhone), appleID: Self.put(start, over: appleID))
  }

  /// When setup ends: the earliest start on record, or `now` when there is none, in both places.
  /// With a copy unknown nothing changes; the next `settle` brings any earlier start into the
  /// state, which keeps the earliest.
  public func begun(now: Date) -> TrialStart {
    guard known else { return self }
    let start = start ?? now
    return TrialStart(
      thisPhone: Self.put(start, over: thisPhone), appleID: Self.put(start, over: appleID))
  }

  /// Both copies answered.
  public var known: Bool { thisPhone != .unknown && appleID != .unknown }

  private static func put(_ start: Date, over reading: Reading) -> Reading {
    if case .unreadable = reading { return reading }
    return .date(start)
  }
}
