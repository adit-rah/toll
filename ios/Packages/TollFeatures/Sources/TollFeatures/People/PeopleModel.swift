import Foundation
import Observation
import TollCore
import TollData
import TollUI

/// People (E4.29, design §4.4): requests, friends, mutuals, contacts, school, invite.
@MainActor
@Observable
public final class PeopleModel {
  let app: AppModel
  public private(set) var people: PeopleResponse?
  public private(set) var schoolMembers: [SchoolMember]?
  public private(set) var requested: Set<String> = []
  public private(set) var error: String?
  public var detail: FriendSummary?
  public var inviteShown = false

  public init(app: AppModel) {
    self.app = app
  }

  public func load() async {
    guard app.isSignedIn else { return }
    do {
      people = try await app.deps.network.people()
      error = nil
    } catch {
      self.error = Copy.Errors.offline
    }
  }

  public func accept(_ userId: String) async {
    try? await app.deps.network.accept(userId)
    await load()
  }

  public func decline(_ userId: String) async {
    try? await app.deps.network.decline(userId)
    await load()
  }

  public func add(_ userId: String, source: String) async {
    _ = try? await app.deps.network.request(userId: userId, source: source)
    requested.insert(userId)
  }

  public func loadSchoolMembers() async {
    schoolMembers = try? await app.deps.network.schoolMembers()
  }
}

/// Friend detail sheet actions (flows §11, §22).
@MainActor
@Observable
public final class PersonActionsModel {
  let app: AppModel
  public var confirmRemove = false
  public var confirmBlock = false
  public var reportShown = false
  public var reportReason: ReportReason = .name
  public var reportText = ""
  public private(set) var reportSent = false
  public var askAlsoBlock = false

  public init(app: AppModel) {
    self.app = app
  }

  public func remove(_ person: PersonRef) async {
    try? await app.deps.network.removeFriend(person.id)
    _ = try? await app.deps.network.refreshHome()
  }

  public func block(_ person: PersonRef) async {
    Haptics.warning()
    try? await app.deps.network.block(person.id)
    _ = try? await app.deps.network.refreshHome()
  }

  public func report(_ person: PersonRef) async {
    let text = reportText.trimmingCharacters(in: .whitespacesAndNewlines)
    try? await app.deps.network.report(person.id, reason: reportReason, text: text.isEmpty ? nil : text)
    reportSent = true
    askAlsoBlock = true
  }
}
