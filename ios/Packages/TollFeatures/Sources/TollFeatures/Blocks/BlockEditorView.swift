@preconcurrency import FamilyControls
@preconcurrency import ManagedSettings
import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// New block and Block · edit (the canvas's Blocks row), pushed from Blocks: the kind (new blocks
/// only), then Apps to block, Hours and Place, then Save. While the block is on, a note says when the
/// changes apply (B-3); Sleep has no Delete.
struct BlockEditorView: View {
  @State private var model: BlockEditorModel
  @Environment(\.dismiss) private var dismiss
  @State private var choosingApps = false
  @State private var choosingPlace = false
  @State private var editingRule: RuleRef?
  @State private var confirmingDelete = false
  @State private var askingAlways = false

  init(app: AppModel, editing id: BlockID?) {
    _model = State(initialValue: BlockEditorModel(app: app, editing: id))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ScreenTitle(model.isNew ? Copy.Blocks.new : model.block.name, kind: .pushed)
        if let end = model.activeUntil {
          NoteCard(
            Copy.Blocks.activeNote(model.block.name, until: Copy.time(end)),
            symbol: .block(model.block.kind)
          )
          .padding(.top, 16)
        }
        if model.isNew { KindChips(model: model).padding(.top, 20) }
        Card {
          row(Copy.Blocks.apps, detail: model.appsSummary, symbol: .apps) {
            choosingApps = true
          }
          ForEach(model.block.schedule.rules.indices, id: \.self) { index in
            let rule = model.block.schedule.rules[index]
            row(
              hoursTitle(index),
              detail: "\(Copy.span(rule.window))\(Copy.middleDot)\(Copy.Blocks.daySpan(rule.days))",
              symbol: .hours
            ) { editingRule = RuleRef(index: index) }
          }
          row(
            Copy.Blocks.place, detail: model.place?.name ?? Copy.Blocks.anywhere,
            symbol: .place
          ) { choosingPlace = true }
        }
        .padding(.top, model.activeUntil == nil ? 20 : 16)
        if let ignored = model.placeIgnored {
          NoteCard(ignored, severity: .degraded) {
            SettingsLink(Copy.Setup.changeInSettings, action: openSystemSettings)
          }
          .padding(.top, 12)
        }
        if model.isSleep {
          Footnote(Copy.Blocks.sleepStays).padding(.top, 12)
        } else if model.isNew {
          Footnote(Copy.Blocks.explainer).padding(.top, 12)
        }
        if let refusal = model.refusal {
          NoteCard(refusal, severity: .broken)
            .padding(.top, 12)
        }
      }
      .tollGutter()
      .padding(.bottom, 24)
    }
    .background(TollColor.bg)
    .tollBottomBar {
      VStack(spacing: 0) {
        if !model.isNew && !model.isSleep {
          DestructiveQuiet(Copy.Blocks.delete) { confirmingDelete = true }
            .padding(.bottom, 10)
        }
        PrimaryButton(saveTitle) {
          if model.asksAboutAlways {
            askingAlways = true
          } else if model.save() {
            dismiss()
          }
        }
        .disabled(!model.canSave)
      }
    }
    .tollPushed(model.isNew ? Copy.Blocks.new : model.block.name)
    .navigationDestination(isPresented: $choosingApps) { BlockAppsView(model: model) }
    .navigationDestination(isPresented: $choosingPlace) {
      PlacePicker(app: model.app, place: model.place) { model.place = $0 }
    }
    .sheet(item: $editingRule) { ref in
      HoursSheet(
        rule: model.block.schedule.rules[ref.index],
        limits: { model.limits(with: $0, at: ref.index) }
      ) { model.setRule(ref.index, $0) }
    }
    .sheet(isPresented: $askingAlways) {
      if let question = model.alwaysQuestion {
        WithoutAlwaysSheet(place: question.place, line: question.body) { only in
          model.block.onlyAtPlace = only
          if model.save() { dismiss() }
        }
      }
    }
    .sheet(isPresented: $confirmingDelete) {
      DeleteBlockSheet(model: model) { if model.delete() { dismiss() } }
    }
  }

  private var saveTitle: String {
    if model.isNew { return Copy.Blocks.save }
    if let end = model.activeUntil { return Copy.Blocks.saveAfter(Copy.time(end)) }
    return Copy.Blocks.saveEdit
  }

  /// Sleep with weekends different has two rules; name them as setup did (#49).
  private func hoursTitle(_ index: Int) -> String {
    guard model.isSleep, model.block.schedule.rules.count == 2 else { return Copy.Blocks.hours }
    return index == 0 ? Copy.Setup.weeknights : Copy.Setup.weekendNights
  }

  private func row(_ title: String, detail: String, symbol: TollSymbol, open: @escaping () -> Void)
    -> some View
  {
    Button(action: open) {
      CardRow(title, detail: detail) {
        IconTile(symbol, accent: false)
      } trailing: {
        Chevron()
      }
    }
    .buttonStyle(.plain)
  }
}

/// Study · Work · Gym · Other: four 76 pt tiles, the chosen one amber.
private struct KindChips: View {
  let model: BlockEditorModel

  var body: some View {
    HStack(spacing: 8) {
      ForEach(model.kinds, id: \.self) { kind in
        let selected = model.block.kind == kind
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Button {
          model.choose(kind)
        } label: {
          VStack(spacing: 6) {
            Image(symbol: .block(kind)).unredacted()
              .font(.system(size: 20, weight: .medium))
              .foregroundStyle(selected ? TollColor.accent : TollColor.label2)
            Text(Copy.Blocks.kindName(kind))
              .tollType(TollType(size: 13, lineHeight: 18, weight: .semibold, style: .footnote))
              .foregroundStyle(TollColor.label)
          }
          .frame(maxWidth: .infinity, minHeight: 76)
          .background(selected ? TollColor.accentSoft : TollColor.surface, in: shape)
          .overlay(shape.strokeBorder(selected ? TollColor.accent : TollColor.separator))
          .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
      }
    }
    .tollHaptic(.selection, trigger: model.block.kind)
  }
}

/// Block · delete: what stops being blocked, and that the other blocks stay.
private struct DeleteBlockSheet: View {
  let model: BlockEditorModel
  let delete: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    // On now, the delete waits for the block to end (B-3), and the sheet says so (#49).
    let end = model.activeUntil.map { Copy.time($0) }
    SheetPage(height: 344, overhang: 16) {
      SheetTitle(Copy.Blocks.deleteTitle(model.block.name))
      SheetBody(
        end.map { Copy.Blocks.deleteHeld(model.block.name, until: $0) }
          ?? Copy.Blocks.deleteLine(model.appsSummary, place: model.place?.name))
    } actions: {
      PrimaryButton(end.map(Copy.Blocks.deleteAt) ?? Copy.Blocks.delete, tone: .warn) {
        dismiss()
        delete()
      }
      QuietButton(Copy.Blocks.cancel) { dismiss() }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
  }
}

/// Without Always, a block tied to a place runs on its hours anywhere or waits for Always; the user
/// chooses when saving (#63).
private struct WithoutAlwaysSheet: View {
  let place: String
  let line: String
  let choose: (Bool) -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    SheetPage(height: 374, overhang: 16) {
      SheetTitle(Copy.Blocks.withoutAlwaysTitle)
      SheetBody(line).padding(.top, 10)
    } actions: {
      PrimaryButton(Copy.Blocks.onlyAt(place)) {
        dismiss()
        choose(true)
      }
      QuietButton(Copy.Blocks.runAnyway) {
        dismiss()
        choose(false)
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 8)
    }
  }
}

/// Which of the schedule's rules the hours sheet is editing.
struct RuleRef: Identifiable {
  let index: Int
  var id: Int { index }
}

/// Block · apps picked: iOS's own rows, the counts against the limit, and Done (off over it).
struct BlockAppsView: View {
  @Bindable var model: BlockEditorModel
  @Environment(\.dismiss) private var dismiss
  @State private var picking = false

  var body: some View {
    let limits = model.limits()
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ScreenTitle(Copy.Blocks.apps, kind: .pushed)
        Card {
          ForEach(Array(model.selection.categoryTokens), id: \.self) { token in
            Label(token).labelStyle(AppRowLabelStyle(detail: Copy.Blocks.wholeCategory))
          }
          ForEach(Array(model.selection.applicationTokens), id: \.self) { token in
            Label(token).labelStyle(AppRowLabelStyle())
          }
          ForEach(Array(model.selection.webDomainTokens), id: \.self) { token in
            Label(token).labelStyle(AppRowLabelStyle(detail: Copy.Blocks.website))
          }
          ChooseMoreRow(
            Blocklist.isEmpty(model.selection) ? Copy.Setup.chooseApps : Copy.Setup.chooseMore
          ) { picking = true }
        }
        .padding(.top, 20)
        HStack {
          Text(Copy.Blocks.thisBlock(Blocklist.items(model.selection)))
            .tollType(.detail, TollColor.label2)
          Spacer(minLength: 8)
          Text(Copy.Blocks.allBlocks(limits.appsUsed, of: limits.appsMax))
            .tollType(
              limits.appsOver > 0 ? .trailing : .detail,
              limits.appsOver > 0 ? TollColor.warn : TollColor.label2)
        }
        .padding(.horizontal, 4)
        .padding(.top, TollSpacing.underCard)
        if limits.appsOver > 0 {
          NoteCard(
            Copy.Blocks.overLimit(limits.appsMax, remove: limits.appsOver),
            severity: .broken
          )
          .padding(.top, 12)
        }
      }
      .tollGutter()
      .padding(.bottom, 24)
    }
    .background(TollColor.bg)
    .animation(Motion.stateChange, value: limits.appsOver)
    .tollBottomBar {
      PrimaryButton(Copy.Setup.done) { dismiss() }
        .disabled(limits.appsOver > 0 || Blocklist.isEmpty(model.selection))
    }
    .tollPushed(Copy.Blocks.apps)
    .familyActivityPicker(isPresented: $picking, selection: $model.selection)
  }
}
