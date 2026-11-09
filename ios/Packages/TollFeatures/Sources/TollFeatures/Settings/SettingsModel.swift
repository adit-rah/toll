import Foundation
import Observation
import TollCore
import TollData

/// Settings (E9.43, design §4.8): account, school, notifications, discoverability, blocks, data, about,
/// and the donation link last.
@MainActor
@Observable
public final class SettingsModel {
  let app: AppModel
  public var notifyEnabled = true
  public var notifyHour = 10
  public var discoverable = true
  public private(set) var blockedPeople: [PersonRef] = []
  public private(set) var exportURL: URL?
  public var confirmSignOut = false
  public var confirmDelete = false
  public var confirmLeaveSchool = false
  public var deleteCodeSent = false
  public var deleteCode = ""
  public private(set) var error: String?

  public init(app: AppModel) {
    self.app = app
    notifyEnabled = app.me?.notifyEnabled ?? true
    notifyHour = app.me?.notifyHour ?? app.config.notify.hour
    discoverable = app.me?.discoverable ?? true
  }

  public var version: String {
    let info = Bundle.main.infoDictionary ?? [:]
    return "\(info["CFBundleShortVersionString"] as? String ?? "") (\(info["CFBundleVersion"] as? String ?? ""))"
  }

  public var legalBase: URL {
    let host = Bundle.main.object(forInfoDictionaryKey: "TollLinkHost") as? String ?? "toll.alders.dev"
    return URL(string: "https://\(host)") ?? URL(filePath: "/")
  }

  public var supportEmail: String {
    "support@\(Bundle.main.object(forInfoDictionaryKey: "TollLinkHost") as? String ?? "toll.alders.dev")"
  }

  /// Ledger B: no donation link exists yet; the row hides until `TollDonationURL` is set.
  public var donationURL: URL? {
    (Bundle.main.object(forInfoDictionaryKey: "TollDonationURL") as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
  }

  public func save() async {
    guard app.isSignedIn else { return }
    do {
      let me = try await app.deps.account.update(
        MePatch(discoverable: discoverable, notifyEnabled: notifyEnabled, notifyHour: notifyHour))
      app.updated(me)
    } catch {
      self.error = Copy.Errors.generic
    }
  }

  public func loadBlockedPeople() async {
    blockedPeople = (try? await app.deps.network.blockedPeople()) ?? []
  }

  public func unblock(_ person: PersonRef) async {
    try? await app.deps.network.unblock(person.id)
    await loadBlockedPeople()
  }

  public func leaveSchool() async {
    try? await app.deps.network.leaveSchool()
    if let me = try? await app.deps.account.refreshMe() { app.updated(me) }
  }

  public func signOut() async {
    await app.deps.account.signOut()
    await app.signedOut()
  }

  /// A JSON file of the user's own events (spec §15 E9.43), built on the device.
  public func prepareExport() async {
    let events = (try? await app.deps.store.allEvents()) ?? []
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(events) else { return }
    let url = FileManager.default.temporaryDirectory.appending(path: "toll-events.json")
    try? data.write(to: url, options: .atomic)
    exportURL = url
  }

  // MARK: Deletion (spec §13): confirm, re-authenticate, delete, wipe.

  public var isEmailAccount: Bool { app.me?.email != nil }

  public func sendDeleteCode() async {
    guard let email = app.me?.email else { return }
    try? await app.deps.account.startEmail(email)
    deleteCodeSent = true
  }

  public func deleteWithEmailCode() async {
    await delete(.email(code: deleteCode))
  }

  public func deleteWithApple(_ credential: AppleCredential, nonce: AppleNonce) async {
    await delete(
      .apple(authorizationCode: credential.authorizationCode, identityToken: credential.identityToken, nonce: nonce.raw))
  }

  private func delete(_ reauth: Reauth) async {
    do {
      try await app.deps.account.deleteAccount(reauth)
      await app.accountDeleted()
    } catch let error as APIError {
      self.error = error.code == "wrong_code" ? Copy.Code.wrong : Copy.Errors.generic
    } catch {
      self.error = Copy.Errors.generic
    }
  }
}
