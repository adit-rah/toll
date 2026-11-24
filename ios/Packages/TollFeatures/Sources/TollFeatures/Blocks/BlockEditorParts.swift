import SwiftUI
import TollCore
import TollUI

/// The editor's title with the block's kind tile before it (#78), so which block this is reads
/// without the name. A new block has no tile until its kind is picked.
struct EditorTitle: View {
  let text: String
  let kind: Block.Kind?

  var body: some View {
    HStack(spacing: 12) {
      if let kind {
        IconTile(.block(kind), size: .large)
          .padding(.top, TollSpacing.pushedTitleGap)
      }
      ScreenTitle(text, kind: .pushed)
    }
  }
}

/// Study · Work · Gym · Other: four 76 pt tiles, the picked one amber, two by two at accessibility
/// sizes. On a new block the first pick opens the apps picker (#89).
struct KindChips: View {
  let model: BlockEditorModel
  let openPicker: (Bool) -> Void
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    let columns = Array(
      repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 2 : 4)
    LazyVGrid(columns: columns, spacing: 8) {
      ForEach(BlockDraft.kinds, id: \.self) { kind in
        let selected = model.kindPicked && model.block.kind == kind
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Button {
          if model.pick(kind) { openPicker(true) }
        } label: {
          VStack(spacing: 6) {
            // One glyph height, so every label sits on the same line (the audit).
            Image(symbol: .block(kind)).unredacted()
              .font(.system(size: 20, weight: .medium))
              .foregroundStyle(selected ? TollColor.accent : TollColor.label2)
              .frame(height: 24)
              .accessibilityHidden(true)
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

/// The block's name, typed in place (#62); it starts as the kind's name. Drawn as a field, with the
/// field's shape and corners (design §2.4), so it reads as editable before it's tapped (the audit).
struct NameRow: View {
  @Binding var name: String
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
      : AnyLayout(HStackLayout(spacing: TollSpacing.rowGap))
    layout {
      Text(Copy.Blocks.name)
        .tollType(.rowTitle, TollColor.label2)
        .accessibilityHidden(true)
      TextField(Copy.Blocks.name, text: $name)
        .tollType(.rowTitle, TollColor.label)
        .submitLabel(.done)
        .accessibilityLabel(Copy.Blocks.name)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(
          TollColor.surfaceRaised,
          in: RoundedRectangle(cornerRadius: TollRadius.field, style: .continuous))
    }
    .padding(.vertical, 8)
    .frame(minHeight: RowSize.compact.minHeight)
  }
}

/// Block · delete: what stops being blocked, and that the other blocks stay.
struct DeleteBlockSheet: View {
  let model: BlockEditorModel
  let delete: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    // On now, the delete waits for the block to end (B-3), and the sheet says so (#49).
    let end = model.activeUntil.map { Copy.time($0) }
    SheetPage(height: 344, overhang: 16) {
      SheetTitle(Copy.Blocks.deleteTitle(model.title))
      SheetBody(
        end.map { Copy.Blocks.deleteHeld(model.title, until: $0) }
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
struct WithoutAlwaysSheet: View {
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
