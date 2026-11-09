import Foundation
import TollCore

#if os(iOS)
  import TollScreenTime
#endif

/// Accounts (E3): sign in with Apple or an email code, identity, device registration, sign-out and
/// deletion. The session token lives in the Keychain; the last `Me` is cached for offline routing.
public actor AccountService {
  let api: APIClient
  let store: LocalStore
  let sync: SyncEngine
  let keychain: Keychain
  let analytics: Analytics

  public init(api: APIClient, store: LocalStore, sync: SyncEngine, keychain: Keychain, analytics: Analytics) {
    self.api = api
    self.store = store
    self.sync = sync
    self.keychain = keychain
    self.analytics = analytics
  }

  public var hasSession: Bool { keychain.string(.sessionToken) != nil }

  public func cachedMe() async -> Me? { try? await store.setting("me", as: Me.self) }

  // MARK: Sign in

  public func signInWithApple(
    identityToken: String, authorizationCode: String, rawNonce: String, givenName: String?, familyName: String?
  ) async throws -> AuthSession {
    struct Body: Codable, Sendable {
      var identityToken, authorizationCode, nonce, deviceId: String
      var givenName, familyName: String?
    }
    let session: AuthSession = try await api.send(
      "POST", "auth/apple",
      json: Body(
        identityToken: identityToken, authorizationCode: authorizationCode, nonce: rawNonce,
        deviceId: keychain.deviceId(), givenName: givenName, familyName: familyName))
    await adopt(session)
    return session
  }

  public func startEmail(_ email: String) async throws {
    try await api.sendNoContent("POST", "auth/email/start", json: ["email": email])
  }

  public func verifyEmail(_ email: String, code: String) async throws -> AuthSession {
    let session: AuthSession = try await api.send(
      "POST", "auth/email/verify", json: ["email": email, "code": code, "deviceId": keychain.deviceId()])
    await adopt(session)
    return session
  }

  private func adopt(_ session: AuthSession) async {
    keychain.set(session.token, for: .sessionToken)
    try? await store.setSetting("me", session.user)
    try? await registerDevice(pushToken: nil)
  }

  /// A solo user who signs in can bring their phone's history along (ledger A2).
  public func uploadLocalHistory() async throws {
    try await sync.uploadHistory()
  }

  /// Without uploading history, only events from now on are sent.
  public func skipLocalHistory() async throws {
    let all = try await store.allEvents()
    try await store.markUploaded(Set(all.map(\.id.lowercasedString)), at: Date())
  }

  // MARK: Identity

  @discardableResult
  public func refreshMe() async throws -> Me {
    let me: Me = try await api.get("me")
    try? await store.setSetting("me", me)
    return me
  }

  @discardableResult
  public func update(_ patch: MePatch) async throws -> Me {
    let me: Me = try await api.send("PATCH", "me", json: patch)
    try? await store.setSetting("me", me)
    return me
  }

  public func handleAvailability(_ handle: String) async throws -> HandleAvailability {
    try await api.get("handles/\(handle)/available")
  }

  public func suggestHandle(for name: String) async throws -> String {
    struct Suggestion: Codable, Sendable { var handle: String }
    let suggestion: Suggestion = try await api.get("handles/suggest", query: ["name": name])
    return suggestion.handle
  }

  @discardableResult
  public func uploadPhoto(_ jpeg: Data) async throws -> Me {
    let me: Me = try await api.upload("me/photo", data: jpeg, contentType: "image/jpeg")
    try? await store.setSetting("me", me)
    return me
  }

  @discardableResult
  public func deletePhoto() async throws -> Me {
    let me: Me = try await api.send("DELETE", "me/photo", json: Empty())
    try? await store.setSetting("me", me)
    return me
  }

  public func registerDevice(pushToken: String?) async throws {
    struct Body: Codable, Sendable {
      var deviceId: String
      var pushToken: String?
      var pushEnvironment: String
      var timezone: String
    }
    #if DEBUG
      let environment = "sandbox"
    #else
      let environment = "production"
    #endif
    try await api.sendNoContent(
      "PUT", "devices",
      json: Body(
        deviceId: keychain.deviceId(), pushToken: pushToken, pushEnvironment: environment,
        timezone: TimeZone.current.identifier))
  }

  // MARK: Leaving

  /// "Sign out? Blocks stay on this phone." Blocks and history stay; only the session goes.
  public func signOut() async {
    try? await api.sendNoContent("POST", "auth/logout", json: Empty?.none)
    keychain.set(nil, for: .sessionToken)
    try? await store.setSetting("me", Me?.none)
  }

  /// Deletion keeps nothing (spec §13): server rows, then every local trace including shields.
  public func deleteAccount(_ reauth: Reauth) async throws {
    struct Body: Codable, Sendable {
      struct ReauthBody: Codable, Sendable {
        var kind: String
        var authorizationCode, identityToken, nonce, code: String?
      }
      var reauth: ReauthBody
    }
    let body: Body =
      switch reauth {
      case .apple(let code, let token, let nonce):
        Body(reauth: .init(kind: "apple", authorizationCode: code, identityToken: token, nonce: nonce, code: nil))
      case .email(let code):
        Body(reauth: .init(kind: "email", authorizationCode: nil, identityToken: nil, nonce: nil, code: code))
      }
    try await api.sendNoContent("DELETE", "account", json: body)
    analytics.send(.accountDeleted)
    await wipeDevice()
  }

  public func wipeDevice() async {
    keychain.set(nil, for: .sessionToken)
    try? await store.wipe()
    #if os(iOS)
      ActivityScheduler().stopAll()
      ShieldReconciler().clearAll()
      try? FileManager.default.removeItem(at: TokenRegistry().url)
    #endif
    SharedGateStore().update { $0 = SharedGateState() }
  }
}
