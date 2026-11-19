@preconcurrency import FamilyControls
@preconcurrency import ManagedSettings
import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// New block / Edit block (the design canvas): kind, place, hours, apps, then Save.
struct BlockEditorView: View {
  @State private var model: BlockEditorModel
  @Environment(\.dismiss) private var dismiss
  @State private var picking = false
  @State private var editingRule: RuleRef?
  @State private var choosingPlace = false
  @State private var confirmingDelete = false

  init(app: AppModel, editing id: BlockID?) {
    _model = State(initialValue: BlockEditorModel(app: app, editing: id))
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: TollSpacing.groupGap) {
          ScreenTitle(model.isNew ? Copy.Blocks.new : model.block.name)
          if !model.isSleep { kindChips }
          Card {
            Button {
              choosingPlace = true
            } label: {
              CardRow(Copy.Blocks.place, detail: model.place?.name ?? Copy.Blocks.anywhere) {
                IconTile("location.fill", accent: false)
              } trailing: {
                Chevron()
              }
            }
            .buttonStyle(.plain)
            ForEach(model.block.schedule.rules.indices, id: \.self) { index in
              let rule = model.block.schedule.rules[index]
              Button {
                editingRule = RuleRef(index: index)
              } label: {
                CardRow(
                  Copy.Blocks.hours,
                  detail: "\(Copy.span(rule.window)) · \(Copy.Blocks.daySpan(rule.days))"
                ) {
                  IconTile("clock", accent: false)
                } trailing: {
                  Chevron()
                }
              }
              .buttonStyle(.plain)
            }
            Button {
              picking = true
            } label: {
              CardRow(
                Copy.Blocks.apps,
                detail: Copy.Blocks.summary(
                  apps: Blocklist.items(model.selection),
                  categories: model.selection.categoryTokens.count)
              ) {
                IconTile("nosign", accent: false)
              } trailing: {
                Chevron()
              }
            }
            .buttonStyle(.plain)
          }
          Footnote(Copy.Blocks.explainer)
          if model.isActive { Footnote(Copy.Blocks.changesLater, symbol: "clock") }
          if let refusal = model.refusal { Footnote(refusal, symbol: "exclamationmark.circle") }
          if !model.isNew && !model.isSleep {
            DestructiveQuiet(Copy.Blocks.delete) { confirmingDelete = true }
          }
        }
        .tollGutter()
        .padding(.bottom, TollSpacing.sectionGap)
      }
      .background(TollColor.bg)
      .tollBottomBar(background: TollColor.bg) {
        PrimaryButton(Copy.Blocks.save) { if model.save() { dismiss() } }
          .disabled(!model.canSave)
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar(.visible, for: .navigationBar)
    }
    .tint(TollColor.accent)
    .familyActivityPicker(isPresented: $picking, selection: $model.selection)
    .sheet(item: $editingRule) { ref in
      HoursSheet(rule: model.block.schedule.rules[ref.index]) { model.setRule(ref.index, $0) }
    }
    .sheet(isPresented: $choosingPlace) {
      PlacePicker(app: model.app, place: model.place) { model.place = $0 }
    }
    .confirmationDialog(
      Copy.Blocks.deleteConfirm, isPresented: $confirmingDelete, titleVisibility: .visible
    ) {
      Button(Copy.Blocks.delete, role: .destructive) { if model.delete() { dismiss() } }
    }
  }

  private var kindChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(model.kinds, id: \.self) { kind in
          let selected = model.block.kind == kind
          Button {
            model.choose(kind)
          } label: {
            Label(Copy.Blocks.kindName(kind), systemImage: BlockSymbol.name(kind))
              .font(TollFont.subheadMedium)
              .padding(.horizontal, 14)
              .frame(minHeight: 40)
              .foregroundStyle(selected ? TollColor.onAccent : TollColor.label)
              .background(selected ? TollColor.accent : TollColor.surface, in: Capsule())
          }
          .accessibilityAddTraits(selected ? .isSelected : [])
        }
      }
    }
    .tollHaptic(.selection, trigger: model.block.kind)
  }
}

private struct Chevron: View {
  var body: some View {
    Image(systemName: "chevron.right").foregroundStyle(TollColor.label3).accessibilityHidden(true)
  }
}

/// Which of the schedule's rules the hours sheet is editing.
struct RuleRef: Identifiable {
  let index: Int
  var id: Int { index }
}
