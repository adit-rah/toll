import Foundation

/// The trial's start, kept twice (P-4, D78): in this phone's Keychain, which outlives deleting the
/// app, and as an iCloud Keychain item, so a new or erased phone on the same Apple ID continues the
/// same free nights. The earliest wins, so neither copy can start them again. With iCloud Keychain
/// off the second copy never leaves the phone and agrees with the first.
public struct TrialStart: Equatable, Sendable {
  public var thisPhone: Date?
  public var appleID: Date?

  public init(thisPhone: Date?, appleID: Date?) {
    self.thisPhone = thisPhone
    self.appleID = appleID
  }

  public var start: Date? { [thisPhone, appleID].compactMap(\.self).min() }

  /// Both copies hold the earliest start: a phone that began before D78 gets its iCloud copy, and
  /// one that began before the iCloud copy arrived takes the earlier date.
  public var settled: TrialStart {
    guard let start else { return self }
    return TrialStart(thisPhone: start, appleID: start)
  }

  /// When setup ends: the earliest start on record, or `now` when there is none, in both places.
  public func begun(now: Date) -> TrialStart {
    let start = start ?? now
    return TrialStart(thisPhone: start, appleID: start)
  }
}
