import Foundation
import StoreKit

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

/// When the trial started, kept in the Keychain so deleting and reinstalling the app does not start
/// another (P-4, decisions D7).
public struct TrialClock: Sendable {
  let keychain: Keychain

  public init(keychain: Keychain = Keychain()) {
    self.keychain = keychain
  }

  public var start: Date? {
    keychain.string(.trialStart).flatMap(Double.init).map(
      Date.init(timeIntervalSinceReferenceDate:))
  }

  /// The first start ever recorded on this phone, recording `now` if there is none.
  public func begin(now: Date) -> Date {
    if let start { return start }
    keychain.set(String(now.timeIntervalSinceReferenceDate), for: .trialStart)
    return now
  }
}
