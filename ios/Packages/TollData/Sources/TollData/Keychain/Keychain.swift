import Foundation
import Security
import Synchronization

/// Values that must outlive a reinstall (MVP spec P-4): the Keychain survives deleting the app.
public struct Keychain: Sendable {
  public enum Key: String, Sendable {
    case trialStart
  }

  /// Where an item lives. `appleID` is an iCloud Keychain item (`kSecAttrSynchronizable`): Apple's
  /// end-to-end-encrypted store for the Apple ID, never a Dusk server (D78). With iCloud Keychain
  /// off it stays on this phone.
  public enum Scope: Sendable {
    case thisPhone, appleID
  }

  let service: String
  private let memory: Memory?

  public init(service: String = "com.advan.toll") {
    self.service = service
    memory = nil
  }

  /// For previews and demo launches: an unsigned simulator build has no Keychain to write to
  /// (docs/renders.md), and a preview must never read or replace the real value.
  public static func inMemory() -> Keychain {
    Keychain(service: "memory", memory: Memory())
  }

  private init(service: String, memory: Memory) {
    self.service = service
    self.memory = memory
  }

  public func string(_ key: Key, in scope: Scope = .thisPhone) -> String? {
    if let memory { return memory.values.withLock { $0[Memory.Slot(key: key, scope: scope)] } }
    var query = base(key, scope)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  public func set(_ value: String?, for key: Key, in scope: Scope = .thisPhone) {
    if let memory {
      memory.values.withLock { $0[Memory.Slot(key: key, scope: scope)] = value }
      return
    }
    SecItemDelete(base(key, scope) as CFDictionary)
    guard let value else { return }
    var query = base(key, scope)
    query[kSecValueData as String] = Data(value.utf8)
    // A synced item can't be tied to this device.
    query[kSecAttrAccessible as String] =
      scope == .appleID
      ? kSecAttrAccessibleAfterFirstUnlock : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(query as CFDictionary, nil)
  }

  /// Toll's session token and device id: useless now its server is gone, and the Keychain keeps them
  /// through reinstalls (decisions D28).
  public func removeTollItems() {
    guard memory == nil else { return }
    for account in ["sessionToken", "deviceId"] {
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
      ]
      SecItemDelete(query as CFDictionary)
    }
  }

  /// Without `kSecAttrSynchronizable` a query matches only this phone's items, so the two scopes
  /// never read or delete each other's.
  private func base(_ key: Key, _ scope: Scope) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key.rawValue,
    ]
    if scope == .appleID { query[kSecAttrSynchronizable as String] = true }
    return query
  }
}

private final class Memory: Sendable {
  struct Slot: Hashable {
    let key: Keychain.Key
    let scope: Keychain.Scope
  }
  let values = Mutex<[Slot: String]>([:])
}
