import SwiftUI
import TollCore
import TollData
import TollUI

/// The sheet Home's bar opens (design §3.18). The same anatomy in every state: icon, title and one
/// line; one body block; at most one primary and one quiet action. It reads the live state, so a
/// wait that ends while it is open turns into the session picker in place. Every action closes it.
struct StateSheet: View {
  let model: HomeModel
  let gate: GateModel
  let onEdit: (BlockRef) -> Void
  let onAddBlock: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    let state = model.barState
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        header(state)
        content(state)
          .padding(.top, TollSpacing.groupGap)
      }
      .tollGutter()
      .padding(.top, 28)
      .padding(.bottom, TollSpacing.cardPadding)
    }
    .scrollBounceBehavior(.basedOnSize)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      actions(state)
        .tollGutter()
        .padding(.bottom, TollSpacing.footerBottom)
        .background(TollColor.bg)
    }
    .background(TollColor.bg)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .animation(Motion.movement, value: gate.phase)
  }

  private func close(then work: @escaping @MainActor () async -> Void) {
    dismiss()
    Task { await work() }
  }

  /// Closes the sheet, then pushes or presents what comes next.
  private func closeAnd(_ next: () -> Void) {
    dismiss()
    next()
  }

  // MARK: Header

  @ViewBuilder
  private func header(_ state: HomeBarState) -> some View {
    switch state {
    case .screenTimeOff:
      SheetHeader(line: model.screenTimeOffSince.map(Self.since)) {
        SymbolTile("shield", tint: TollColor.level3)
      } title: {
        Text(Copy.Bar.screenTimeOff)
      }
    case .needsRepicking:
      SheetHeader(line: Copy.Bar.needsRepickingLine) {
        SymbolTile("shield", tint: TollColor.level3)
      } title: {
        Text(Copy.Bar.needsRepicking)
      }
    case .nothingYet:
      SheetHeader(line: Copy.Bar.chooseApps) {
        SymbolTile("shield")
      } title: {
        Text(Copy.Bar.nothingYet)
      }
    case .nothingNow(let next, let apps):
      SheetHeader(line: HomeBarState.startsLine(next, apps: apps)) {
        SymbolTile("clock")
      } title: {
        Text(Copy.Bar.nothingNow)
      }
    case .blocked(let active, let next):
      SheetHeader(line: blockedNowLine(active, next: next)) {
        SymbolTile("shield", tint: TollColor.accent)
      } title: {
        Text(Copy.Sheet.blockedNow)
      }
    case .waiting, .choosing:
      SheetHeader(line: gateLine(state)) {
        AppTile(gate.titleApps.first)
      } title: {
        AppNames(gate.titleApps)
      }
    case .open(_, let session):
      SheetHeader(line: openedLine(session)) {
        AppTile(session.appRefs.first)
      } title: {
        NamesThen(session.appRefs) { Text(Copy.Bar.isOpenSuffix) }
      }
    }
  }

  private func blockedNowLine(_ active: [BlockState], next: BlockState?) -> String {
    let apps = HomeBarState.apps(of: active).count
    guard let next, case .starts(let time) = next.line else {
      return Copy.Sheet.blockedNowLine(apps: apps, next: nil)
    }
    return Copy.Sheet.blockedNowLine(apps: apps, next: (next.block.appRefs.count, time))
  }

  private func gateLine(_ state: HomeBarState) -> String? {
    if case .waiting = gate.phase {
      let refs = Set(gate.titleApps)
      let block = model.blockStates.first { !refs.isDisjoint(with: $0.block.appRefs) }
      return block.map { Copy.Sheet.blockedBy(Copy.Schedules.kind($0.block.schedule)) }
    }
    guard let pending = model.app.gate.pendingPass else { return nil }
    return pending.free ? Copy.Sheet.freeUnlock : Copy.Sheet.waited(pending.waitMinutes)
  }

  private func openedLine(_ session: ActiveSession) -> String {
    Copy.Sheet.opened(
      at: model.clockTime(of: session.startedAt), locks: model.clockTime(of: session.expiresAt))
  }

  /// "Since Tuesday", "Since today".
  private static func since(_ day: HomeModel.OffSince) -> String {
    switch day {
    case .today: Copy.Sheet.offSince(Copy.Sheet.today)
    case .yesterday: Copy.Sheet.offSince(Copy.Sheet.yesterday)
    case .weekday(let name): Copy.Sheet.offSince(name)
    }
  }

  // MARK: Body

  @ViewBuilder
  private func content(_ state: HomeBarState) -> some View {
    switch state {
    case .screenTimeOff:
      SheetCard {
        VStack(alignment: .leading, spacing: 6) {
          Text(Copy.Sheet.screenTimeOffBody).font(TollFont.subhead).foregroundStyle(TollColor.label)
          Text(
            Copy.Sheet.screenTimeOffFriends(days: model.app.config.network.silenceMissedCheckins)
          )
          .tollText(.caption)
        }
      }
    case .needsRepicking(let ids):
      BlockList(states: model.blockStates.filter { ids.contains($0.id) }) { id in
        closeAnd { onEdit(id) }
      }
      note(Copy.Sheet.tapToRepick)
    case .nothingYet:
      note(Copy.Sheet.nothingYetLine)
    case .nothingNow, .blocked:
      BlockList(states: BlockStates.active(model.blockStates) + BlockStates.idle(model.blockStates))
      { id in
        closeAnd { onEdit(id) }
      }
      note(Copy.Sheet.tapToEdit)
    case .waiting, .choosing:
      GateSheetBody(gate: gate)
    case .open(let block, let session):
      if case .open(let until) = block.line {
        SheetCard {
          SessionProgress(
            startedAt: session.startedAt, endsAt: until, total: Copy.minutes(session.minutes))
        }
        note(Copy.Sheet.sessionNote(locks: model.clockTime(of: until)))
      }
    }
  }

  private func note(_ text: String) -> some View {
    Text(text)
      .tollText(.caption)
      .padding(.top, 10)
      .padding(.horizontal, 4)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: Actions

  @ViewBuilder
  private func actions(_ state: HomeBarState) -> some View {
    switch state {
    case .screenTimeOff:
      PrimaryButton(Copy.Sheet.turnOnScreenTime) { close { await model.fixScreenTime() } }
    case .nothingYet:
      PrimaryButton(Copy.Blocks.add) { closeAnd { onAddBlock() } }
    case .nothingNow, .blocked:
      QuietButton(Copy.Blocks.add) { closeAnd { onAddBlock() } }
        .disabled(!model.canAddBlock)
    case .needsRepicking:
      EmptyView()
    case .open(let block, _):
      PrimaryButton(Copy.Sheet.lockNow) {
        Haptics.light()
        close { await model.blockAgain(block) }
      }
    case .waiting, .choosing:
      GateSheetActions(gate: gate) { work in close(then: work) }
    }
  }
}

/// The blocks, one row each: icons, names, and what the block is doing now. A row opens the block.
struct BlockList: View {
  let states: [BlockState]
  let onEdit: (BlockRef) -> Void

  var body: some View {
    SheetCard(padding: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)) {
      VStack(spacing: 0) {
        ForEach(Array(states.enumerated()), id: \.element.id) { index, state in
          if index > 0 { Hairline() }
          Button {
            onEdit(state.id)
          } label: {
            row(state)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func row(_ state: BlockState) -> some View {
    HStack(spacing: TollSpacing.rowLeadingGap) {
      AppIconCluster(state.block.appRefs, size: 24)
      VStack(alignment: .leading, spacing: 0) {
        AppNames(state.block.appRefs)
          .font(TollFont.bodyMedium)
          .foregroundStyle(TollColor.label)
        Text(Self.line(state)).tollText(.caption).monospacedDigit()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Image(systemName: "chevron.right")
        .font(TollFont.captionMedium)
        .foregroundStyle(TollColor.label3)
        .accessibilityHidden(true)
    }
    .frame(minHeight: TollSpacing.friendRowMinHeight)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }

  /// "Always · on now", "Nights · from 11 pm".
  static func line(_ state: BlockState) -> String {
    let kind = Copy.Schedules.kind(state.block.schedule)
    switch state.line {
    case .open: return Copy.Sheet.openNow(kind)
    case .always, .until, .passReady: return Copy.Sheet.onNow(kind)
    case .starts(let time): return Copy.Sheet.from(kind, time)
    case .unscheduled: return kind
    }
  }
}
