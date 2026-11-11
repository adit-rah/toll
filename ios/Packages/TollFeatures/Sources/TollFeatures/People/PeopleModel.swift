import Foundation
import Observation
import SwiftUI
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
  public private(set) var schoolError: String?
  public private(set) var requested: Set<String> = []
  public private(set) var error: String?
  /// Friends as Home last saw them, shown until `/people` answers so the tab never opens on the empty
  /// line and then fills in.
  private var cachedFriends: [FriendSummary] = []
  // A slower, older answer must not overwrite a newer one (an accept racing the load on appear).
  @ObservationIgnored private var generation = 0

  public init(app: AppModel) {
    self.app = app
  }

  public var friends: [FriendSummary] { people?.friends ?? cachedFriends }
  public var hasLoaded: Bool { people != nil }

  public func load() async {
    guard app.isSignedIn else { return }
    generation += 1
    let mine = generation
    if people == nil, cachedFriends.isEmpty {
      cachedFriends = await app.deps.network.cachedHome()?.friends ?? []
    }
    do {
      let fresh = try await app.deps.network.people()
      guard mine == generation else { return }
      error = nil
      apply(fresh)
    } catch {
      // Leaving the tab cancels the request; that is not a lost connection.
      if mine == generation, !Task.isCancelled { self.error = Copy.Errors.offline }
    }
  }

  private func apply(_ fresh: PeopleResponse) {
    guard fresh != people else { return }
    if people == nil {
      people = fresh
    } else {
      // Design §2.5: on refresh rows move to their new places, and a removed friend's row collapses.
      withAnimation(Motion.movement) { people = fresh }
    }
  }

  public func accept(_ userId: String) async {
    var failed = false
    do { try await app.deps.network.accept(userId) } catch { failed = true }
    await reload(afterFailure: failed)
  }

  public func decline(_ userId: String) async {
    var failed = false
    do { try await app.deps.network.decline(userId) } catch { failed = true }
    await reload(afterFailure: failed)
  }

  /// The request row is still there after an answer that did not land, so the line says why. A reload
  /// that fails too has already said "No connection."; one that works clears the line, so this is set
  /// after it.
  private func reload(afterFailure failed: Bool) async {
    await load()
    if failed, error == nil { error = Copy.Errors.generic }
  }

  public func isRequested(_ userId: String) -> Bool {
    requested.contains(userId) || (people?.outgoing.contains { $0.id == userId } ?? false)
  }

  /// The row says "Requested" at once and goes back to "Add" if the request did not land.
  public func add(_ userId: String, source: String) async {
    guard !requested.contains(userId) else { return }
    requested.insert(userId)
    do {
      let result = try await app.deps.network.request(userId: userId, source: source)
      // They had already asked: the request made a friendship, so the lists changed.
      if result.status == "accepted" { await load() }
    } catch {
      requested.remove(userId)
    }
  }

  /// The row a mutual or a school member ends with.
  func addAction(for userId: String, source: String) -> MutualRow.Trailing {
    if isRequested(userId) { return .note(Copy.People.requested) }
    return .add(title: Copy.People.add, action: { Task { await self.add(userId, source: source) } })
  }

  public func loadSchoolMembers() async {
    do {
      schoolMembers = try await app.deps.network.schoolMembers()
      schoolError = nil
    } catch {
      if !Task.isCancelled { schoolError = Copy.Errors.offline }
    }
  }
}
