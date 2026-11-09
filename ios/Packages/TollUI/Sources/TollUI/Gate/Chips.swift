import SwiftUI
import TollCore

/// A 34 pt selectable chip inside a 44 pt hit area. Selected is the accent fill.
public struct ChoiceChip: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  public init(_ title: String, isSelected: Bool, action: @escaping () -> Void) {
    self.title = title
    self.isSelected = isSelected
    self.action = action
  }

  public var body: some View {
    Button(title, action: action)
      .buttonStyle(ChipStyle(isSelected: isSelected))
      .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

private struct ChipStyle: ButtonStyle {
  let isSelected: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(TollFont.subheadMedium)
      .monospacedDigit()
      .lineLimit(1)
      .foregroundStyle(isSelected ? TollColor.onAccent : TollColor.label)
      .padding(.horizontal, 14)
      .frame(minHeight: 34)
      .background(
        isSelected ? TollColor.accent : TollColor.surfaceRaised,
        in: RoundedRectangle(cornerRadius: TollRadius.chip, style: .continuous)
      )
      .animation(Motion.stateChange, value: isSelected)
      .frame(minHeight: TollSpacing.minTapTarget)
      .contentShape(Rectangle())
      .opacity(configuration.isPressed ? 0.7 : 1)
  }
}

/// Design §3.9. The seven tags, wrapped and centred. Once one is chosen the others fade out (200 ms) so
/// the chosen chip is the last thing on screen before the section collapses.
public struct TagChips: View {
  let tags: [Tag]
  @Binding var selection: Tag?
  let fadesOthersOnSelect: Bool

  public init(
    tags: [Tag] = Tag.allCases, selection: Binding<Tag?>, fadesOthersOnSelect: Bool = true
  ) {
    self.tags = tags
    _selection = selection
    self.fadesOthersOnSelect = fadesOthersOnSelect
  }

  public var body: some View {
    FlowLayout(spacing: 8) {
      ForEach(tags, id: \.self) { tag in
        let faded = fadesOthersOnSelect && selection != nil && selection != tag
        ChoiceChip(Copy.Tags.chip(tag), isSelected: selection == tag) {
          selection = tag
        }
        .opacity(faded ? 0 : 1)
        .disabled(faded)
        .accessibilityHidden(faded)
        .animation(Motion.stateChange, value: selection)
      }
    }
    .tollHaptic(.selection, trigger: selection)
  }
}

/// Rows of subviews that wrap at the proposed width, centred by default.
public struct FlowLayout: Layout {
  let spacing: CGFloat
  let lineSpacing: CGFloat
  let centred: Bool

  public init(spacing: CGFloat = 8, lineSpacing: CGFloat = 0, centred: Bool = true) {
    self.spacing = spacing
    self.lineSpacing = lineSpacing
    self.centred = centred
  }

  public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ())
    -> CGSize
  {
    let maxWidth = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? .infinity
    let rows = arrange(subviews, maxWidth: maxWidth)
    let height =
      rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
    let usedWidth = rows.map(\.width).max() ?? 0
    return CGSize(width: maxWidth.isFinite ? maxWidth : usedWidth, height: height)
  }

  public func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var y = bounds.minY
    for row in arrange(subviews, maxWidth: bounds.width) {
      var x = centred ? bounds.minX + (bounds.width - row.width) / 2 : bounds.minX
      for item in row.items {
        subviews[item.index].place(
          at: CGPoint(x: x, y: y + (row.height - item.size.height) / 2),
          anchor: .topLeading,
          proposal: ProposedViewSize(item.size))
        x += item.size.width + spacing
      }
      y += row.height + lineSpacing
    }
  }

  private struct Item {
    var index: Int
    var size: CGSize
  }

  private struct Row {
    var items: [Item] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> [Row] {
    var rows: [Row] = []
    var current = Row()
    for index in subviews.indices {
      var size = subviews[index].sizeThatFits(.unspecified)
      size.width = min(size.width, maxWidth)
      if !current.items.isEmpty, current.width + spacing + size.width > maxWidth {
        rows.append(current)
        current = Row()
      }
      current.width += (current.items.isEmpty ? 0 : spacing) + size.width
      current.height = max(current.height, size.height)
      current.items.append(Item(index: index, size: size))
    }
    if !current.items.isEmpty { rows.append(current) }
    return rows
  }
}
