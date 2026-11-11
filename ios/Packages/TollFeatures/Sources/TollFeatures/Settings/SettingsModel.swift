import CoreTransferable
import Foundation
import Observation
import TollCore
import TollData
import UniformTypeIdentifiers

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
  public private(set) var blockedAppCount: Int?
  public var confirmSignOut = false
  public var confirmDelete = false
  public var confirmLeaveSchool = false
  public private(set) var deleteCodeSent = false
  public var deleteCode = ""
  /// Bumped on a wrong code so the boxes shake and clear (design §2.5).
  public private(set) var deleteShake = 0
  public private(set) var saveError: String?
  public private(set) var deleteError: String?

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

  /// Runs each time Settings comes back to the front, so the count is right after a visit to Blocks.
  public func refresh() async {
    let blocks = (try? await app.deps.store.blocks()) ?? []
    let count = Set(blocks.flatMap(\.appRefs)).count
    if count != blockedAppCount { blockedAppCount = count }
    await loadBlockedPeople()
  }

  public func save() async {
    guard app.isSignedIn, let me = app.me else { return }
    let savedHour = me.notifyHour ?? app.config.notify.hour
    // Nothing to send; this is also what stops the revert below from saving a second time.
    guard discoverable != me.discoverable || notifyEnabled != me.notifyEnabled || notifyHour != savedHour
    else { return }
    do {
      let updated = try await app.deps.account.update(
        MePatch(discoverable: discoverable, notifyEnabled: notifyEnabled, notifyHour: notifyHour))
      app.updated(updated)
      saveError = nil
    } catch {
      // A switch left on that the server never accepted would be a lie.
      discoverable = me.discoverable
      notifyEnabled = me.notifyEnabled
      notifyHour = savedHour
      saveError = Copy.Errors.generic
    }
  }

  /// "Open Settings" under "Notifications are off" (flows §16). iOS shows its sheet only if it never
  /// has (setup skips it when Screen Time was turned on from the Settings app); after that it answers
  /// no at once and the switch is in the Settings app. Toll rereads the answer as it returns.
  public func allowNotifications() async {
    if await NotificationPermission.request() {
      await app.recheckNotifications()
    } else {
      await app.openSystemSettings()
    }
  }

  public func loadBlockedPeople() async {
    guard app.isSignedIn else { return }
    let people = (try? await app.deps.network.blockedPeople()) ?? []
    if people != blockedPeople { blockedPeople = people }
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

  public var export: EventsExport { EventsExport(store: app.deps.store) }

  // MARK: Deletion (spec §13): confirm, re-authenticate, delete, wipe.

  public var isEmailAccount: Bool { app.me?.email != nil }

  /// Every opening starts from the first step, whatever an earlier attempt left behind.
  public func beginDelete() {
    deleteCodeSent = false
    deleteCode = ""
    deleteError = nil
    confirmDelete = true
  }

  public func sendDeleteCode() async {
    guard let email = app.me?.email else { return }
    do {
      try await app.deps.account.startEmail(email)
      deleteCodeSent = true
      deleteError = nil
    } catch {
      deleteError = Copy.Errors.generic
    }
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
      confirmDelete = false
      await app.accountDeleted()
    } catch let error as APIError {
      if error.code == "wrong_code" {
        deleteError = Copy.Code.wrong
        deleteShake += 1
      } else {
        deleteError = Copy.Errors.generic
      }
    } catch {
      deleteError = Copy.Errors.generic
    }
  }
}

/// A JSON file of the user's own events (spec §15 E9.43), built on the device when a share target
/// asks for it: one tap, and nothing is read or encoded just because Settings was opened.
public struct EventsExport: Transferable, Sendable {
  let store: LocalStore

  public static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .json) { export in
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let events = try await export.store.allEvents()
      return try encoder.encode(events)
    }
    .suggestedFileName("toll-events.json")
  }
}
