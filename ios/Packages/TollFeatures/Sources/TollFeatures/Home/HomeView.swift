import SwiftUI
import TollCore
import TollData
import TollUI

/// Home (design §4.1): you, centred; then pinned lines; then friends by improvement. The dock (the
/// Toll-opens caption and the block bar) sits on the tab bar, wherever the list has scrolled.
struct HomeView: View {
  let app: AppModel
  @State private var model: HomeModel?
  @State private var path = NavigationPath()
  @State private var detail: FriendSummary?
  @State private var inviteShown = false
  @State private var blocksShown = false
  @State private var personAction: (PersonAction, PersonRef)?
  @Namespace private var barSpace
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        if let model { content(model) }
      }
      .background(TollColor.bg)
      .refreshable { await model?.refresh() }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        HomeDock(app: app, model: model, barSpace: barSpace) { blocksShown = true }
      }
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button { path.append(HomeRoute.newBlock) } label: { Image(systemName: "plus") }
            .accessibilityLabel(Copy.Blocks.add)
            .disabled(!canAddBlock)
          Button { path.append(HomeRoute.settings) } label: { Image(systemName: "gearshape") }
            .accessibilityLabel(Copy.Settings.title)
        }
      }
      .navigationDestination(for: HomeRoute.self) { route in
        switch route {
        case .settings: SettingsView(app: app)
        case .blocks: BlocksView(app: app)
        case .newBlock: BlockEditorView(app: app, mode: .new)
        case .editBlock(let id): BlockEditorView(app: app, mode: .edit(id))
        }
      }
      .sheet(item: $detail) { friend in
        FriendDetailView(app: app, friend: friend) { Task { await model?.refresh() } }
      }
      .sheet(isPresented: $inviteShown) { InviteSheet(app: app) }
      .sheet(isPresented: $blocksShown) {
        blockCards.navigationTransition(.zoom(sourceID: HomeDock.barID, in: barSpace))
      }
      .personActions(app: app, pending: $personAction) { Task { await model?.refresh() } }
    }
    .task {
      if model == nil { model = HomeModel(app: app) }
      await model?.start()
    }
    .onChange(of: app.gate) { _, _ in Task { await model?.gateChanged() } }
    // Fix can send the person to the Settings app; the device line is read again when they return.
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await model?.cameToFront() } }
    }
    // Sheets present above the gate's card, so one left open would hide a wait that has just
    // started, or the session picker of a free pass.
    .onChange(of: gateCardIsUp) { _, isUp in
      if isUp {
        detail = nil
        inviteShown = false
        blocksShown = false
      }
    }
  }

  private var gateCardIsUp: Bool {
    app.gate.wait != nil || app.gate.pendingPass?.deferred == false
  }

  private var canAddBlock: Bool {
    BlockLimits.canAddBlock(existing: model?.blockStates.count ?? 0, config: app.config.blocks)
  }

  @ViewBuilder
  private var blockCards: some View {
    if let model {
      BlockCardsSheet(
        model: model, onUnblock: { unblock($0) }, onBlockAgain: { blockAgain($0) },
        onEdit: { edit($0) },
        onBlocks: {
          blocksShown = false
          path.append(HomeRoute.blocks)
        })
    }
  }

  /// The gate's card arrives beneath any sheet, so this one closes before the request is made.
  private func unblock(_ state: BlockState) {
    blocksShown = false
    Task { await model?.unblock(state) }
  }

  private func blockAgain(_ state: BlockState) {
    Haptics.light()
    Task { await model?.blockAgain(state) }
  }

  private func edit(_ block: BlockRef) {
    blocksShown = false
    path.append(HomeRoute.editBlock(block))
  }

  @ViewBuilder
  private func content(_ model: HomeModel) -> some View {
    VStack(spacing: 0) {
      deviceLine(model)
      hero(model)
        .padding(.top, TollSpacing.heroTop)
        .padding(.bottom, TollSpacing.heroToList)
      ForEach(model.home?.pinned ?? [], id: \.self) { pin in
        Button { detail = model.home?.friends.first { $0.user.id == pin.user.id } } label: {
          PinnedRow(FriendFormatting.pinned(pin))
        }
        .buttonStyle(.plain)
        .tollTransition(Motion.pinnedLine)
      }
      friends(model)
    }
    .padding(.bottom, TollSpacing.sectionGap)
    .tollGutter()
    .animation(Motion.movement, value: model.home)
  }

  @ViewBuilder
  private func deviceLine(_ model: HomeModel) -> some View {
    switch model.deviceState {
    case .screenTimeOff:
      PinnedRow(Copy.Home.screenTimeOff, actionTitle: Copy.Home.fix) { Task { await model.fixScreenTime() } }
    case .blocksNeedRepicking(let only)?:
      PinnedRow(Copy.Home.blocksNeedRepicking, actionTitle: Copy.Home.fix) {
        // One block: straight to its apps. Several: the list, where each one is marked.
        if let only {
          path.append(HomeRoute.editBlock(only))
        } else {
          path.append(HomeRoute.blocks)
        }
      }
    case .nothingBlocked:
      PinnedRow(Copy.Home.nothingBlocked, actionTitle: Copy.Home.addApps) { path.append(HomeRoute.newBlock) }
    case .none:
      EmptyView()
    }
  }

  /// A button, not a tap gesture, so VoiceOver can open Insights from here too.
  private func hero(_ model: HomeModel) -> some View {
    Button {
      app.tab = .insights
    } label: {
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
    }
    .buttonStyle(.plain)
    .onAppear { model.markAppeared() }
  }

  @ViewBuilder
  private func friends(_ model: HomeModel) -> some View {
    if app.isSignedIn {
      SectionHeader(Copy.Home.friendsHeader, trailing: model.home?.friendsHeldPercent.map(Copy.Home.friendsHeldShort))
        .padding(.bottom, 4)
      if let stale = model.staleSince {
        Text(Copy.Home.lastSynced(stale.formatted(.relative(presentation: .named))))
          .tollText(.caption)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      let friends = model.home?.friends ?? []
      if friends.isEmpty {
        if model.friendsUnavailable {
          // Same place and size as the empty line it stands in for.
          EmptyState(Copy.Errors.offline).padding(.vertical, 24)
        } else {
          EmptyState(Copy.Home.noFriends, actionTitle: Copy.Home.sendInvite) { inviteShown = true }
            .padding(.vertical, 24)
        }
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
