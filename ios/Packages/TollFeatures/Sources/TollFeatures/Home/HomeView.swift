import SwiftUI
import TollCore
import TollData
import TollUI

/// Home (design §4.1): you, centred, with three facts beneath; then pinned lines; then friends by
/// improvement; then the Toll-opens line. The state bar sits on the tab bar, wherever the list has
/// scrolled, and opens the one sheet that says more.
struct HomeView: View {
  let app: AppModel
  let gate: GateModel?
  @State private var model: HomeModel?
  @State private var path = NavigationPath()
  @State private var detail: FriendSummary?
  @State private var inviteShown = false
  @State private var sheetShown = false
  @State private var personAction: (PersonAction, PersonRef)?
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        if let model { content(model) }
      }
      .background(TollColor.bg)
      .refreshable { await model?.refresh() }
      .safeAreaInset(edge: .bottom, spacing: 0) { bar }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            path.append(HomeRoute.settings)
          } label: {
            Image(systemName: "gearshape")
          }
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
      .sheet(isPresented: $sheetShown) {
        if let model, let gate {
          StateSheet(
            model: model, gate: gate, onEdit: { path.append(HomeRoute.editBlock($0)) },
            onAddBlock: { path.append(HomeRoute.newBlock) })
        }
      }
      .personActions(app: app, pending: $personAction) { Task { await model?.refresh() } }
    }
    .task {
      if model == nil { model = HomeModel(app: app) }
      await model?.start()
    }
    .onChange(of: app.gate) { _, _ in Task { await model?.gateChanged() } }
    // Turn on Screen Time can send the person to the Settings app; the permission is read again when
    // they return.
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await model?.cameToFront() } }
    }
    // A wait that starts, or a pass that arrives, opens the sheet by itself. Only one sheet shows at
    // a time, so any other closes first.
    .onChange(of: gate?.prompt, initial: true) { _, _ in openForGate() }
  }

  private func openForGate() {
    guard let gate, gate.prompt != gate.promptSeen else { return }
    gate.promptSeen = gate.prompt
    detail = nil
    inviteShown = false
    sheetShown = true
  }

  @ViewBuilder
  private var bar: some View {
    if let model {
      HomeBarView(state: model.barState, gateLine: gate?.waitLine, waitEndsAt: gate?.waitEndsAt) {
        openBar(model)
      }
      .tollGutter()
      .padding(.top, TollSpacing.labelGap)
      .padding(.bottom, TollSpacing.footerBottom)
    }
  }

  /// A pass set aside with Not now comes back to the picker before the sheet opens on it.
  private func openBar(_ model: HomeModel) {
    if case .choosing(let pending) = model.barState, pending.deferred {
      Task {
        await model.resume()
        sheetShown = true
      }
    } else {
      sheetShown = true
    }
  }

  @ViewBuilder
  private func content(_ model: HomeModel) -> some View {
    VStack(spacing: 0) {
      hero(model)
        .padding(.top, TollSpacing.heroTop)
        .padding(.bottom, TollSpacing.sectionGap)
      ForEach(model.home?.pinned ?? [], id: \.self) { pin in
        Button {
          detail = model.home?.friends.first { $0.user.id == pin.user.id }
        } label: {
          PinnedRow(FriendFormatting.pinned(pin))
        }
        .buttonStyle(.plain)
        .tollTransition(Motion.pinnedLine)
      }
      friends(model)
      Text(Copy.Home.tollOpens(app.tollOpensToday))
        .tollText(.caption)
        .foregroundStyle(TollColor.label3)
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, TollSpacing.cardPadding)
    }
    .padding(.bottom, TollSpacing.sectionGap)
    .tollGutter()
    .animation(Motion.movement, value: model.home)
  }

  /// A button, not a tap gesture, so VoiceOver can open Insights from here too.
  private func hero(_ model: HomeModel) -> some View {
    VStack(spacing: 0) {
      Button {
        app.tab = .insights
      } label: {
        HeroStat(
          value: model.you.passesToday, mark: StatusMark(level: model.you.level),
          unit: Copy.Home.unlocksToday(model.you.passesToday),
          statusSpeech: model.you.level.map {
            Copy.Status.label($0, personalised: model.personalised)
          }
        )
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      HomeFacts(you: model.you, blockedApps: model.blockedApps, today: model.today)
        .padding(.top, 20)
      Button {
        app.tab = .insights
      } label: {
        WeekStrip(
          counts: model.you.strip, todayIndex: model.you.todayIndex,
          animateOnAppear: !model.hasAppeared)
      }
      .buttonStyle(.plain)
      .padding(.top, 18)
    }
    .frame(maxWidth: .infinity)
    .onAppear { model.markAppeared() }
  }

  @ViewBuilder
  private func friends(_ model: HomeModel) -> some View {
    if app.isSignedIn {
      SectionHeader(
        Copy.Home.friendsHeader,
        trailing: model.home?.friendsHeldPercent.map(Copy.Home.friendsWalkedAwayShort)
      )
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
        Button {
          detail = friend
        } label: {
          FriendRow(
            name: friend.user.displayName, handle: friend.user.handle,
            photoURL: FriendFormatting.photo(friend.user),
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
