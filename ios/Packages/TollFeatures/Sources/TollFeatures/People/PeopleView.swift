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

  /// Person rows carry their own height and centre themselves, so the list adds no vertical inset.
  static let rowInsets = EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
  private static let headerInsets = EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4)

  var body: some View {
    let signedIn = app.isSignedIn
    NavigationStack {
      ZStack {
        TollColor.bgGrouped.ignoresSafeArea()
        if !signedIn {
          EmptyState(Copy.People.signInToAdd, actionTitle: Copy.People.signIn) {
            app.showsSignInSheet = true
          }
          .tollGutter()
        } else if let model {
          list(model)
        }
      }
      .navigationTitle(Copy.People.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if signedIn {
          ToolbarItem(placement: .topBarTrailing) {
            Button { inviteShown = true } label: { Image(systemName: "person.badge.plus") }
              .accessibilityLabel(Copy.People.invite)
          }
        }
      }
      .sheet(item: $detail) { friend in
        FriendDetailView(app: app, friend: friend) { reload() }
      }
      .sheet(isPresented: $inviteShown) { InviteSheet(app: app) }
      .personActions(app: app, pending: $personAction) { reload() }
      // Joining a school from the field below turns that section into the school's row.
      .onChange(of: app.me?.school) { _, _ in reload() }
    }
    .task(id: signedIn) {
      guard signedIn else {
        model = nil
        return
      }
      if model == nil { model = PeopleModel(app: app) }
      await model?.load()
    }
  }

  private func reload() {
    Task { await model?.load() }
  }

  private func list(_ model: PeopleModel) -> some View {
    List {
      if let error = model.error {
        Section {
          Text(error)
            .tollText(.subhead)
            .listRowInsets(Self.headerInsets)
            .listRowBackground(Color.clear)
        }
      }
      requests(model)
      friends(model)
      // Everything below comes only from `/people`; drawing it empty first would flash the wrong
      // sections (no mutuals, no school) and then swap them.
      if model.hasLoaded {
        mutuals(model)
        school(model)
        findFriends
      }
      invite
    }
    .listStyle(.insetGrouped)
    .refreshable { await model.load() }
  }

  private func header(_ title: String) -> some View {
    SectionHeader(title).listRowInsets(Self.headerInsets)
  }

  @ViewBuilder
  private func requests(_ model: PeopleModel) -> some View {
    if let requests = model.people?.requests, !requests.isEmpty {
      Section {
        ForEach(requests) { request in
          FriendRow(
            name: request.user.displayName, handle: request.user.handle,
            photoURL: FriendFormatting.photo(request.user), status: nil,
            detail: request.mutualNames.first.map(Copy.People.requestVia)
              ?? "@\(request.user.handle)",
            detailStyle: .regular,
            trailing: .request(
              acceptTitle: Copy.People.accept, declineTitle: Copy.People.decline,
              onAccept: { Task { await model.accept(request.user.id) } },
              onDecline: { Task { await model.decline(request.user.id) } }),
            speech: FriendRow.Speech(), separatorAbove: false, backing: TollColor.surface
          )
          .listRowInsets(Self.rowInsets)
          .contextMenu { PersonMenu(isFriend: false) { personAction = ($0, request.user) } }
        }
      } header: {
        header(Copy.People.requests)
      }
    }
  }

  @ViewBuilder
  private func friends(_ model: PeopleModel) -> some View {
    let friends = model.friends
    if model.hasLoaded || !friends.isEmpty {
      Section {
        if friends.isEmpty {
          EmptyState(Copy.Home.noFriends, actionTitle: Copy.Home.sendInvite) { inviteShown = true }
        }
        ForEach(friends) { friend in
          Button {
            detail = friend
          } label: {
            FriendRow(
              name: friend.user.displayName, handle: friend.user.handle,
              handleCaption: "@\(friend.user.handle)",
              photoURL: FriendFormatting.photo(friend.user), status: FriendFormatting.mark(friend),
              detail: FriendFormatting.weekLine(friend), detailStyle: .regular,
              trailing: FriendFormatting.weekTrend(friend), speech: FriendFormatting.speech(friend),
              separatorAbove: false, backing: TollColor.surface)
          }
          .buttonStyle(.plain)
          .listRowInsets(Self.rowInsets)
          .contextMenu { PersonMenu(isFriend: true) { personAction = ($0, friend.user) } }
        }
      } header: {
        header(
          friends.isEmpty
            ? Copy.People.friends : Copy.People.friends + Copy.middleDot + "\(friends.count)")
      }
    }
  }

  @ViewBuilder
  private func mutuals(_ model: PeopleModel) -> some View {
    if let mutuals = model.people?.mutuals, !mutuals.isEmpty {
      Section {
        ForEach(mutuals) { mutual in
          let level = mutual.level.flatMap(StatusLevel.init(rawValue:))
          MutualRow(
            name: mutual.user.displayName, handle: mutual.user.handle,
            photoURL: FriendFormatting.photo(mutual.user), status: StatusMark(level: level),
            detail: Copy.FriendRows.mutual(via: mutual.via.first ?? "", others: mutual.viaCount - 1),
            trend: mutual.trend.map(Trend.init(fraction:)),
            trailing: model.addAction(for: mutual.user.id, source: "mutual"),
            statusSpeech: FriendFormatting.statusSpeech(level),
            trendSpeech: Copy.FriendRows.trendAccessibility(mutual.trend), separatorAbove: false,
            backing: TollColor.surface
          )
          .listRowInsets(Self.rowInsets)
          .contextMenu { PersonMenu(isFriend: false) { personAction = ($0, mutual.user) } }
        }
      } header: {
        header(Copy.People.mutuals)
      }
    }
  }

  @ViewBuilder
  private func school(_ model: PeopleModel) -> some View {
    Section {
      if let school = model.people?.school {
        NavigationLink {
          SchoolMembersView(app: app, model: model, school: school.name)
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text(school.name).tollText(.headline)
            Text(Copy.People.schoolLine(members: school.members, heldPercent: school.heldPercent))
              .tollText(.subhead)
              .monospacedDigit()
          }
          .padding(.vertical, 8)
          .frame(minHeight: TollSpacing.friendRowMinHeight)
        }
        .listRowInsets(Self.rowInsets)
        .accessibilityHint(Copy.People.findAtSchool(school.name))
      } else {
        embedded(FindFriendsView(app: app, isSetup: false, parts: [.school], showsHeaders: false))
      }
    } header: {
      header(Copy.People.school)
    }
  }

  /// Entering a friend's code and matching contacts stay here for good (N-17), not only in setup.
  private var findFriends: some View {
    Section {
      embedded(FindFriendsView(app: app, isSetup: false, parts: [.inviteCode, .contacts]))
    }
  }

  // The fields are their own shapes, so they sit straight on the page, edge to edge with the cards
  // above, instead of as boxes inside a list row.
  private func embedded(_ view: FindFriendsView) -> some View {
    view
      .listRowInsets(EdgeInsets())
      .listRowBackground(Color.clear)
  }

  private var invite: some View {
    Section {
      if let code = app.me?.inviteCode {
        LabeledContent(Copy.Invite.yourCode, value: code)
      }
    } header: {
      header(Copy.People.invite)
    } footer: {
      Button(Copy.People.shareInvite) { inviteShown = true }
        .buttonStyle(.tollPrimary)
        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 0, trailing: 0))
    }
  }
}
