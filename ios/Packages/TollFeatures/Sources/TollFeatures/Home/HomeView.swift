import SwiftUI
import TollCore
import TollData
import TollUI

/// Home (design §4.1): you, centred; then pinned lines; then friends by improvement; the Toll-opens
/// footer last and quietest.
struct HomeView: View {
  let app: AppModel
  @State private var model: HomeModel?
  @State private var path = NavigationPath()
  @State private var detail: FriendSummary?
  @State private var inviteShown = false
  @State private var personAction: (PersonAction, PersonRef)?

  enum Destination: Hashable { case settings, newBlock }

  var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        if let model { content(model) }
      }
      .background(TollColor.bg)
      .refreshable { await model?.refresh() }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button { path.append(Destination.settings) } label: { Image(systemName: "gearshape") }
            .accessibilityLabel(Copy.Settings.title)
        }
      }
      .navigationDestination(for: Destination.self) { destination in
        switch destination {
        case .settings: SettingsView(app: app)
        case .newBlock: BlockEditorView(app: app, mode: .new)
        }
      }
      .sheet(item: $detail) { friend in FriendDetailView(app: app, friend: friend) }
      .sheet(isPresented: $inviteShown) { InviteSheet(app: app) }
      .personActions(app: app, pending: $personAction) { Task { await model?.refresh() } }
    }
    .task {
      if model == nil { model = HomeModel(app: app) }
      await model?.start()
    }
    .onChange(of: app.gate) { _, _ in Task { await model?.updateDeviceState() } }
  }

  @ViewBuilder
  private func content(_ model: HomeModel) -> some View {
    VStack(spacing: 0) {
      deviceLine(model)
      if let session = model.activeSession, let ref = session.appRefs.first {
        HStack(spacing: 4) {
          AppLabel(ref)
          Text(Copy.Home.sessionActiveRest(minutes: session.minutes))
        }
        .tollText(.bodyMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .transition(Motion.pinnedLine)
      }
      hero(model)
        .padding(.top, TollSpacing.heroTop)
        .padding(.bottom, TollSpacing.heroToList)
      ForEach(Array((model.home?.pinned ?? []).enumerated()), id: \.offset) { _, pin in
        Button { detail = model.home?.friends.first { $0.user.id == pin.user.id } } label: {
          PinnedRow(FriendFormatting.pinned(pin))
        }
        .buttonStyle(.plain)
        .transition(Motion.pinnedLine)
      }
      friends(model)
      Spacer(minLength: 32)
      Text(Copy.Home.tollOpens(app.tollOpensToday))
        .tollText(.caption)
        .foregroundStyle(TollColor.label3)
        .padding(.bottom, 24)
    }
    .tollGutter()
    .animation(Motion.movement, value: model.home)
  }

  @ViewBuilder
  private func deviceLine(_ model: HomeModel) -> some View {
    switch model.deviceState {
    case .screenTimeOff:
      PinnedRow(Copy.Home.screenTimeOff, actionTitle: Copy.Home.fix) { Task { await model.fixScreenTime() } }
    case .blocksNeedRepicking:
      PinnedRow(Copy.Home.blocksNeedRepicking, actionTitle: Copy.Home.fix) { path.append(Destination.settings) }
    case .nothingBlocked:
      PinnedRow(Copy.Home.nothingBlocked, actionTitle: Copy.Home.addApps) { path.append(Destination.newBlock) }
    case .none:
      EmptyView()
    }
  }

  private func hero(_ model: HomeModel) -> some View {
    VStack(spacing: 14) {
      HeroStat(
        value: model.you.passesToday, mark: StatusMark(level: model.you.level),
        unit: Copy.Home.passesToday(model.you.passesToday),
        subhead: Copy.Home.week(model.you.thisWeek, last: model.you.lastWeek),
        statusSpeech: model.you.level.map { Copy.Status.label($0, personalised: model.personalised) })
      WeekStrip(
        counts: model.you.strip, todayIndex: model.you.todayIndex, animateOnAppear: !model.hasAppeared)
    }
    .frame(maxWidth: .infinity)
    .contentShape(Rectangle())
    .onTapGesture { app.tab = .insights }
    .onAppear { model.markAppeared() }
  }

  @ViewBuilder
  private func friends(_ model: HomeModel) -> some View {
    if app.isSignedIn {
      SectionHeader(Copy.Home.friendsHeader, trailing: model.home?.friendsHeldPercent.map(Copy.Home.friendsHeldShort))
      if let stale = model.staleSince {
        Text(Copy.Home.lastSynced(stale.formatted(.relative(presentation: .named))))
          .tollText(.caption)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      let friends = model.home?.friends ?? []
      if friends.isEmpty {
        EmptyState(Copy.Home.noFriends, actionTitle: Copy.Home.sendInvite) { inviteShown = true }
          .padding(.vertical, 24)
      }
      ForEach(Array(friends.enumerated()), id: \.element.id) { index, friend in
        Button { detail = friend } label: {
          FriendRow(
            name: friend.user.displayName, handle: friend.user.handle, photoURL: FriendFormatting.photo(friend.user),
            status: FriendFormatting.mark(friend), detail: FriendFormatting.detail(friend),
            trailing: FriendFormatting.trailing(friend), speech: FriendFormatting.speech(friend),
            separatorAbove: index > 0)
        }
        .buttonStyle(.plain)
        .contextMenu { PersonMenu(isFriend: true) { personAction = ($0, friend.user) } }
      }
    }
  }
}
