import SwiftUI
import TollCore
import TollUI

/// The chosen apps (design §4.3, §4.6). Setup shows three and a "+N more" row so the step keeps its
/// shape whatever the picker returns; New block lists them all with their friends-facing tags.
struct BlockAppsCard: View {
  let model: BlockEditorModel
  let fill: Color
  @Binding var showAll: Bool

  private static let setupVisible = 3

  var body: some View {
    let visible = model.isSetup ? Array(model.refs.prefix(Self.setupVisible)) : model.refs
    let hidden = model.refs.count - visible.count
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(visible.enumerated()), id: \.element) { index, ref in
        if index > 0 { Hairline() }
        appRow(ref)
          .staggeredAppearance(index: index, step: Motion.Stagger.pickerRows, rise: 6)
      }
      if hidden > 0 {
        Hairline()
        moreRow(hidden)
      }
      if !model.refs.isEmpty { Hairline() }
      chooseRow
    }
    .padding(.horizontal, TollSpacing.cardPadding)
    .background(fill, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }

  private func appRow(_ ref: AppRef) -> some View {
    HStack(spacing: TollSpacing.rowLeadingGap) {
      AppLabel(ref, style: .both).tollText(.body).lineLimit(1)
      Spacer(minLength: TollSpacing.labelGap)
      if !model.isSetup {
        Menu {
          ForEach(Tag.allCases, id: \.self) { tag in
            Button(Copy.Tags.chip(tag)) { Task { await model.setTag(tag, for: ref) } }
          }
        } label: {
          Text(model.tags[ref].map(Copy.Tags.chip) ?? Copy.Tags.display(nil))
            .tollText(.caption)
            .frame(minHeight: TollSpacing.minTapTarget)
            .contentShape(Rectangle())
        }
      }
    }
    .frame(minHeight: TollSpacing.rowMinHeight)
    .contentShape(Rectangle())
    .contextMenu {
      Button(Copy.Blocks.remove, role: .destructive) { model.remove(ref) }
    }
  }

  private func moreRow(_ hidden: Int) -> some View {
    Button {
      showAll = true
    } label: {
      HStack(spacing: TollSpacing.labelGap) {
        Text(Copy.BlockEditor.more(hidden)).tollText(.subhead).monospacedDigit()
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(TollFont.captionMedium)
          .foregroundStyle(TollColor.label3)
          .accessibilityHidden(true)
      }
      .frame(minHeight: TollSpacing.minTapTarget)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  /// "Choose apps" centred while the card is empty, so the one thing to do is the whole card; once
  /// there are apps it becomes the last row, on their leading edge.
  private var chooseRow: some View {
    let isEmpty = model.refs.isEmpty
    return Button {
      model.pickerPresented = true
    } label: {
      Label(isEmpty ? Copy.BlockEditor.chooseApps : Copy.BlockEditor.chooseMore, systemImage: "plus")
        .font(TollFont.bodyMedium)
        .foregroundStyle(TollColor.accent)
        .frame(maxWidth: .infinity, minHeight: TollSpacing.rowMinHeight, alignment: isEmpty ? .center : .leading)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
