import CryptoKit
import Foundation
import TollCore

/// Friends, mutuals, school, invites, safety and the social insights (E4, E8.38). Home's response is
/// cached so the screen renders offline and on cold launch before the network answers.
public actor NetworkService {
  let api: APIClient
  let store: LocalStore
  let analytics: Analytics

  public init(api: APIClient, store: LocalStore, analytics: Analytics) {
    self.api = api
    self.store = store
    self.analytics = analytics
  }

  // MARK: Home

  public func cachedHome() async -> HomeResponse? { try? await store.setting("home", as: HomeResponse.self) }

  public func refreshHome() async throws -> HomeResponse {
    let home: HomeResponse = try await api.get("home")
    try? await store.setSetting("home", home)
    return home
  }

  // MARK: People

  public func people() async throws -> PeopleResponse { try await api.get("people") }

  public func request(userId: String, source: String) async throws -> FriendRequestResult {
    let result: FriendRequestResult = try await api.send("POST", "friends/requests", json: ["userId": userId])
    if result.status == "accepted" { analytics.send(.friendAdded(source: source)) }
    return result
  }

  public func request(code: String) async throws -> FriendRequestResult {
    let result: FriendRequestResult = try await api.send(
      "POST", "friends/requests", json: ["code": code.uppercased()])
    if result.status == "accepted" { analytics.send(.friendAdded(source: "invite")) }
    return result
  }

  public func accept(_ userId: String) async throws {
    try await api.sendNoContent("POST", "friends/requests/\(userId)/accept", json: Empty?.none)
    analytics.send(.friendAdded(source: "request"))
  }

  public func decline(_ userId: String) async throws {
    try await api.sendNoContent("POST", "friends/requests/\(userId)/decline", json: Empty?.none)
  }

  public func removeFriend(_ userId: String) async throws {
    try await api.sendNoContent("DELETE", "friends/\(userId)", json: Empty?.none)
  }

  // MARK: Invites

  public func invite() async throws -> Invite {
    if let cached = try? await store.setting("invite", as: Invite.self) { return cached }
    let invite: Invite = try await api.send("POST", "invites", json: Empty())
    try? await store.setSetting("invite", invite)
    return invite
  }

  public func previewInvite(_ code: String) async throws -> InvitePreview {
    try await api.get("invites/\(code.uppercased())")
  }

  // MARK: Contacts (N-12): hashed on the device, raw contacts never leave it.

  public func matchContacts(emails: [String], phones: [String]) async throws -> [PersonRef] {
    struct Salt: Codable, Sendable { var salt: String }
    struct Matches: Codable, Sendable { var matches: [PersonRef] }
    let salt: Salt = try await api.get("contacts/salt")
    let normalized =
      emails.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
      + phones.map { $0.filter { $0.isNumber || $0 == "+" } }
    let hashes = Array(Set(normalized.filter { !$0.isEmpty }.map { Self.hash(salt.salt + $0) })).prefix(2000)
    let result: Matches = try await api.send("POST", "contacts/match", json: ["hashes": Array(hashes)])
    return result.matches
  }

  static func hash(_ text: String) -> String {
    SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  // MARK: School (N-8)

  public func startSchool(email: String) async throws {
    try await api.sendNoContent("POST", "school/start", json: ["email": email])
  }

  public func verifySchool(email: String, code: String) async throws -> SchoolRef {
    try await api.send("POST", "school/verify", json: ["email": email, "code": code])
  }

  public func leaveSchool() async throws {
    try await api.sendNoContent("DELETE", "school", json: Empty?.none)
  }

  public func school() async throws -> SchoolStatus { try await api.get("school") }

  public func schoolMembers() async throws -> [SchoolMember] {
    struct Members: Codable, Sendable { var members: [SchoolMember] }
    let response: Members = try await api.get("school/members")
    return response.members
  }

  // MARK: Safety (N-14, N-15)

  public func block(_ userId: String) async throws {
    try await api.sendNoContent("POST", "person-blocks/\(userId)", json: Empty?.none)
  }

  public func unblock(_ userId: String) async throws {
    try await api.sendNoContent("DELETE", "person-blocks/\(userId)", json: Empty?.none)
  }

  public func blockedPeople() async throws -> [PersonRef] {
    struct People: Codable, Sendable { var people: [PersonRef] }
    let response: People = try await api.get("person-blocks")
    return response.people
  }

  public func report(_ userId: String, reason: ReportReason, text: String?) async throws {
    struct Body: Codable, Sendable {
      var userId: String
      var reason: ReportReason
      var text: String?
    }
    try await api.sendNoContent("POST", "reports", json: Body(userId: userId, reason: reason, text: text))
  }

  // MARK: Insights (I-10…I-19)

  public func friendsInsights(week: TollDay) async throws -> FriendsInsights {
    try await api.get("insights/friends", query: ["week": week.description])
  }

  public func schoolInsights(week: TollDay) async throws -> SchoolInsights {
    try await api.get("insights/school", query: ["week": week.description])
  }
}
