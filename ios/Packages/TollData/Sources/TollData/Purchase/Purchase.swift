import Foundation
import StoreKit
import TollCore

/// The one non-consumable (P-4). StoreKit is the only network the app uses (spec §2).
public enum Purchase {
  /// Set up in App Store Connect as a non-consumable at $9.99 (docs/apple-setup.md).
  public static let productID = "com.advan.toll.full"

  public enum Outcome: Sendable, Equatable {
    case purchased, cancelled, pending, failed
  }

  public static func displayPrice() async -> String? {
    try? await Product.products(for: [productID]).first?.displayPrice
  }

  public static func isPurchased() async -> Bool {
    for await result in Transaction.currentEntitlements {
      if case .verified(let transaction) = result, transaction.productID == productID,
        transaction.revocationDate == nil
      {
        return true
      }
    }
    return false
  }

  public static func buy() async -> Outcome {
    guard let product = try? await Product.products(for: [productID]).first else { return .failed }
    do {
      switch try await product.purchase() {
      case .success(.verified(let transaction)):
        await transaction.finish()
        return .purchased
      case .success(.unverified):
        return .failed
      case .userCancelled:
        return .cancelled
      case .pending:
        return .pending
      @unknown default:
        return .failed
      }
    } catch {
      return .failed
    }
  }

  /// Asks the App Store for this Apple Account's purchases, then reads them.
  public static func restore() async -> Bool {
    try? await AppStore.sync()
    return await isPurchased()
  }

  /// Purchases that finish outside the app's own flow: Ask to Buy approvals, refunds, another phone.
  public static func watch(_ onChange: @escaping @Sendable (Bool) async -> Void) async {
    for await result in Transaction.updates {
      if case .verified(let transaction) = result { await transaction.finish() }
      await onChange(await isPurchased())
    }
  }
}

/// When the trial started: in this phone's Keychain, so deleting and reinstalling the app does not
/// start another (P-4, decisions D7), and in iCloud Keychain, so a new phone on the same Apple ID
/// continues it (D78). `TrialStart` decides which date wins.
public struct TrialClock: Sendable {
  let keychain: Keychain

  public init(keychain: Keychain = Keychain()) {
    self.keychain = keychain
  }

  public var start: Date? { stored.start }

  /// The earliest start, written to whichever place lacks it or holds a later one.
  @discardableResult
  public func settle() -> Date? {
    let stored = stored
    write(stored.settled, over: stored)
    return stored.start
  }

  /// The first start ever recorded for this phone or Apple ID, recording `now` if there is none.
  public func begin(now: Date) -> Date {
    let stored = stored
    let begun = stored.begun(now: now)
    write(begun, over: stored)
    return begun.start ?? now
  }

  private var stored: TrialStart {
    TrialStart(thisPhone: read(.thisPhone), appleID: read(.appleID))
  }

  /// A value that isn't the frozen format is unreadable, never "no start" (#140).
  private func read(_ scope: Keychain.Scope) -> TrialStart.Reading {
    let item: Keychain.Item
    switch keychain.lookup(.trialStart, in: scope) {
    case .missing: return .none
    case .unknown: return .unknown
    case .found(let found): item = found
    }
    guard let seconds = item.text.flatMap(Double.init), seconds.isFinite else {
      return .unreadable(writtenAt: item.writtenAt)
    }
    return .date(Date(timeIntervalSinceReferenceDate: seconds))
  }

  /// `TrialStart` never changes an unreadable copy, so this never writes over one, and with either
  /// copy unknown it changes neither.
  private func write(_ new: TrialStart, over old: TrialStart) {
    if new.thisPhone != old.thisPhone, case .date(let date) = new.thisPhone {
      save(date, in: .thisPhone)
    }
    if new.appleID != old.appleID, case .date(let date) = new.appleID { save(date, in: .appleID) }
  }

  private func save(_ date: Date, in scope: Keychain.Scope) {
    keychain.set(String(date.timeIntervalSinceReferenceDate), for: .trialStart, in: scope)
  }
}
