import Foundation
import Observation
import TollCore
import TollData
import UIKit

/// Invite code, contacts and school (flows §6, §21). Set up 4 uses it once; People keeps the same
/// actions forever (N-17).
@MainActor
@Observable
public final class FindFriendsModel {
  public enum ContactsState: Equatable { case notAsked, denied, loading, matched([PersonRef]) }
  public enum SchoolState: Equatable { case entering, codeSent, joined(String) }

  let app: AppModel
  public var code: String
  public private(set) var codeResult: String?
  public private(set) var codeError: String?
  public private(set) var contacts: ContactsState = ContactsReader.isDenied ? .denied : .notAsked
  public private(set) var requested: Set<String> = []
  public var schoolEmail = ""
  public var schoolCode = ""
  public private(set) var school: SchoolState = .entering
  public private(set) var schoolError: String?
  public private(set) var isWorking = false

  public init(app: AppModel) {
    self.app = app
    code = app.pendingInviteCode ?? ""
    if let name = app.me?.school?.name { school = .joined(name) }
  }

  /// Arriving from an invite link sends the request at once (spec §9 paths).
  public func start() async {
    if !code.isEmpty { await submitCode() }
  }

  public func paste() async {
    if let text = UIPasteboard.general.string {
      code = Self.extractCode(text)
      await submitCode()
    }
  }

  static func extractCode(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if let url = URL(string: trimmed), let index = url.pathComponents.firstIndex(of: "i"),
      index + 1 < url.pathComponents.count
    {
      return url.pathComponents[index + 1].uppercased()
    }
    return trimmed.uppercased()
  }

  public func submitCode() async {
    let value = Self.extractCode(code)
    guard !value.isEmpty else { return }
    isWorking = true
    defer { isWorking = false }
    do {
      let result = try await app.deps.network.request(code: value)
      codeResult = Copy.Friends.requestSent(to: result.user.displayName)
      codeError = nil
      app.pendingInviteCode = nil
    } catch {
      codeError = Copy.Friends.noSuchCode
      codeResult = nil
    }
  }

  public func findContacts() async {
    contacts = .loading
    guard let read = await ContactsReader.read() else {
      contacts = .denied
      return
    }
    let matches = (try? await app.deps.network.matchContacts(emails: read.emails, phones: read.phones)) ?? []
    contacts = .matched(matches)
  }

  public func add(_ person: PersonRef, source: String) async {
    _ = try? await app.deps.network.request(userId: person.id, source: source)
    requested.insert(person.id)
  }

  public func sendSchoolCode() async {
    isWorking = true
    defer { isWorking = false }
    do {
      try await app.deps.network.startSchool(email: schoolEmail.trimmingCharacters(in: .whitespaces).lowercased())
      school = .codeSent
      schoolError = nil
    } catch let error as APIError {
      schoolError = error.code == "not_a_school" ? Copy.Friends.notASchool : Copy.Errors.generic
    } catch {
      schoolError = Copy.Errors.generic
    }
  }

  public func verifySchool() async {
    schoolCode = String(schoolCode.filter(\.isNumber).prefix(6))
    guard schoolCode.count == 6 else { return }
    isWorking = true
    defer { isWorking = false }
    do {
      let joined = try await app.deps.network.verifySchool(email: schoolEmail, code: schoolCode)
      school = .joined(joined.name)
      schoolError = nil
      if let me = try? await app.deps.account.refreshMe() { app.updated(me) }
    } catch let error as APIError {
      schoolError = error.code == "expired" ? Copy.Code.expired : Copy.Code.wrong
      schoolCode = ""
    } catch {
      schoolError = Copy.Errors.generic
    }
  }

  public func finish(skipped: Bool) async {
    app.deps.analytics.send(.onboardingStep(step: "friends", skipped: skipped))
    await app.finishFriendsStep()
  }
}
