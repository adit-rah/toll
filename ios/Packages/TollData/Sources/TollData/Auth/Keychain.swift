import Foundation
import Security

/// The session token and device id (spec §11.1). The Keychain survives uninstall, which is what lets a
/// reinstall skip Welcome (O-1).
public struct Keychain: Sendable {
  public enum Key: String, Sendable {
    case sessionToken, deviceId
  }

  let service: String

  public init(service: String = "com.advan.toll") {
    self.service = service
  }

  public func string(_ key: Key) -> String? {
    var query = base(key)
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

  public func set(_ value: String?, for key: Key) {
    SecItemDelete(base(key) as CFDictionary)
    guard let value else { return }
    var query = base(key)
    query[kSecValueData as String] = Data(value.utf8)
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(query as CFDictionary, nil)
  }

  /// A stable id for this phone, created once.
  public func deviceId() -> String {
    if let existing = string(.deviceId) { return existing }
    let id = UUID().uuidString.lowercased()
    set(id, for: .deviceId)
    return id
  }

  private func base(_ key: Key) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key.rawValue,
    ]
  }
}
