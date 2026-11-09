import SwiftUI
import TollCore
import TollData
import TollUI

/// People (design §4.4, flows §12). A solo user sees one line and Sign in (flows §20).
struct PeopleView: View {
  let app: AppModel
  @State private var model: PeopleModel?
  @State private var detail: FriendSummary?
  @State private var inviteShown = false
  @State private var personAction: (PersonAction, PersonRef)?

  var body: some View {
    NavigationStack {
      Group {
        if !app.isSignedIn {
          EmptyState(Copy.People.signInToAdd, actionTitle: Copy.People.signIn) { app.showsSignInSheet = true }
        } else if let model {
          list(model)
        }
      }
      .navigationTitle(Copy.People.title)
      .toolbar {
        if app.isSignedIn {
          ToolbarItem(placement: .topBarTrailing) {
            Button { inviteShown = true } label: { Image(systemName: "person.badge.plus") }
              .accessibilityLabel(Copy.People.invite)
          }
        }
      }
      .sheet(item: $detail) { FriendDetailView(app: app, friend: $0) }
      .sheet(isPresented: $inviteShown) { InviteSheet(app: app) }
      .personActions(app: app, pending: $personAction) { Task { await model?.load() } }
    }
    .task {
      if model == nil { model = PeopleModel(app: app) }
      await model?.load()
    }
  }

  private func list(_ model: PeopleModel) -> some View {
    List {
      if let requests = model.people?.requests, !requests.isEmpty {
        Section(Copy.People.requests) {
          ForEach(requests) { request in
            FriendRow(
              name: request.user.displayName, handle: request.user.handle,
              photoURL: FriendFormatting.photo(request.user), status: nil,
              detail: request.mutualNames.first.map(Copy.People.requestVia) ?? "@\(request.user.handle)",
              trailing: .request(
                acceptTitle: Copy.People.accept, declineTitle: Copy.People.decline,
                onAccept: { Task { await model.accept(request.user.id) } },
                onDecline: { Task { await model.decline(request.user.id) } }),
              speech: FriendRow.Speech(), separatorAbove: false)
          }
        }
      }
      Section(Copy.People.friends) {
        let friends = model.people?.friends ?? []
        if friends.isEmpty {
          EmptyState(Copy.Home.noFriends, actionTitle: Copy.Home.sendInvite) { inviteShown = true }
        }
        ForEach(friends) { friend in
          Button { detail = friend } label: {
            FriendRow(
              name: friend.user.displayName, handle: friend.user.handle, handleCaption: "@\(friend.user.handle)",
              photoURL: FriendFormatting.photo(friend.user), status: FriendFormatting.mark(friend),
              detail: FriendFormatting.detail(friend), trailing: FriendFormatting.trailing(friend),
              speech: FriendFormatting.speech(friend), separatorAbove: false)
          }
          .buttonStyle(.plain)
          .contextMenu { PersonMenu(isFriend: true) { personAction = ($0, friend.user) } }
        }
      }
      if let mutuals = model.people?.mutuals, !mutuals.isEmpty {
        Section(Copy.People.mutuals) {
          ForEach(mutuals) { mutual in
            MutualRow(
              name: mutual.user.displayName, handle: mutual.user.handle, photoURL: FriendFormatting.photo(mutual.user),
              status: StatusMark(level: mutual.level.flatMap(StatusLevel.init(rawValue:))),
              detail: Copy.FriendRows.mutual(via: mutual.via.first ?? "", others: mutual.viaCount - 1),
              trend: mutual.trend.map(Trend.init(fraction:)),
              addTitle: model.requested.contains(mutual.user.id) ? Copy.People.requested : Copy.People.add,
              statusSpeech: FriendFormatting.statusSpeech(mutual.level.flatMap(StatusLevel.init(rawValue:))),
              trendSpeech: Copy.FriendRows.trendAccessibility(mutual.trend), separatorAbove: false
            ) { Task { await model.add(mutual.user.id, source: "mutual") } }
            .contextMenu { PersonMenu(isFriend: false) { personAction = ($0, mutual.user) } }
          }
        }
      }
      Section(Copy.People.school) {
        if let school = model.people?.school {
          NavigationLink {
            SchoolMembersView(app: app, model: model, school: school.name)
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(school.name).tollText(.headline)
              Text(Copy.People.schoolLine(members: school.members, heldPercent: school.heldPercent)).tollText(.subhead)
              Text(Copy.People.findAtSchool(school.name)).tollText(.caption).foregroundStyle(TollColor.accent)
            }
          }
        } else {
          FindFriendsView(app: app, isSetup: false)
        }
      }
      Section(Copy.People.invite) {
        Button(Copy.People.shareInvite) { inviteShown = true }.buttonStyle(.tollPrimary)
      }
    }
    .refreshable { await model.load() }
  }
}

/// School members and mutuals at the school (flows §12). Nobody is ranked (N-8).
struct SchoolMembersView: View {
  let app: AppModel
  let model: PeopleModel
  let school: String

  var body: some View {
    List(model.schoolMembers ?? []) { member in
      HStack {
        Avatar(name: member.user.displayName, handle: member.user.handle, photoURL: FriendFormatting.photo(member.user))
        VStack(alignment: .leading) {
          Text(member.user.displayName).tollText(.headline)
          Text("@\(member.user.handle)").tollText(.caption)
        }
        Spacer()
        if member.relation == "none" && !model.requested.contains(member.user.id) {
          QuietButton(Copy.People.add) { Task { await model.add(member.user.id, source: "school") } }
        } else if member.relation == "requested" || model.requested.contains(member.user.id) {
          Text(Copy.People.requested).tollText(.caption)
        }
      }
    }
    .navigationTitle(school)
    .task { await model.loadSchoolMembers() }
  }
}
