import SwiftUI

/// The canvas's grouped card: `surface`, 18 pt corners, 16 pt sides, rows split by hairlines.
public struct Card<Content: View>: View {
  let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    VStack(spacing: 0) {
      Group(subviews: content) { rows in
        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
          if index > 0 { Hairline() }
          row
        }
      }
    }
    .padding(.horizontal, TollSpacing.cardPadding)
    .background(
      TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }
}

/// A rounded square holding one SF Symbol. Amber on soft amber when it leads (Sleep, the block
/// that is on); grey on `surfaceRaised` otherwise.
public struct IconTile: View {
  let symbol: String
  let size: TileSize
  let isAccent: Bool
  @ScaledMetric(relativeTo: .callout) private var scale: CGFloat = 1

  public init(_ symbol: String, size: TileSize = .row, accent: Bool = true) {
    self.symbol = symbol
    self.size = size
    self.isAccent = accent
  }

  public var body: some View {
    let grow = min(scale, 1.5)
    Image(systemName: symbol)
      .font(.system(size: size.symbol * grow, weight: .medium))
      .foregroundStyle(isAccent ? TollColor.accent : TollColor.label2)
      .frame(width: size.side * grow, height: size.side * grow)
      .background(
        isAccent ? TollColor.accentSoft : TollColor.surfaceRaised,
        in: RoundedRectangle(cornerRadius: size.radius * grow, style: .continuous)
      )
      .accessibilityHidden(true)
  }
}

/// A card row: leading tile, a 16/21 medium title, an optional 13/18 detail 1 pt under it, and a
/// trailing view. The row is at least its `RowSize` tall and grows with its text; at accessibility
/// sizes the trailing view moves under the text rather than squeezing it.
public struct CardRow<Leading: View, Trailing: View>: View {
  let title: String
  let detail: String?
  let size: RowSize
  let leading: Leading
  let trailing: Trailing
  @Environment(\.dynamicTypeSize) private var typeSize

  public init(
    _ title: String, detail: String? = nil, size: RowSize = .regular,
    @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing
  ) {
    self.title = title
    self.detail = detail
    self.size = size
    self.leading = leading()
    self.trailing = trailing()
  }

  public var body: some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
      : AnyLayout(HStackLayout(spacing: TollSpacing.rowGap))
    layout {
      HStack(spacing: TollSpacing.rowGap) {
        leading
        RowText(title: title, detail: detail)
      }
      trailing
    }
    .padding(.vertical, 8)
    .frame(minHeight: size.minHeight)
    .contentShape(Rectangle())
  }
}

extension CardRow where Trailing == EmptyView {
  public init(
    _ title: String, detail: String? = nil, size: RowSize = .regular,
    @ViewBuilder leading: () -> Leading
  ) {
    self.init(title, detail: detail, size: size, leading: leading) { EmptyView() }
  }
}

/// A row's title and detail, for rows whose title is not a plain string.
public struct RowText: View {
  let title: String
  let detail: String?
  var titleColor = TollColor.label

  public init(title: String, detail: String?, titleColor: Color = TollColor.label) {
    self.title = title
    self.detail = detail
    self.titleColor = titleColor
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(title).tollType(.rowTitle, titleColor)
      if let detail {
        Text(detail).tollType(.detail, TollColor.label2)
      }
    }
    .fixedSize(horizontal: false, vertical: true)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The 8 × 14 chevron at the end of a row that opens something.
public struct Chevron: View {
  public init() {}

  public var body: some View {
    Image(systemName: "chevron.right")
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(TollColor.label3)
      .accessibilityHidden(true)
  }
}

/// A card holding one short fact: an optional 20 pt symbol, then 14/19 text (the canvas's notes: "Sleep is on
/// until 7:00 am…", over-limit lines).
public struct NoteCard<Accessory: View>: View {
  let text: String
  let symbol: String?
  let tint: Color
  let accessory: Accessory

  public init(
    _ text: String, symbol: String? = nil, tint: Color = TollColor.label2,
    @ViewBuilder accessory: () -> Accessory
  ) {
    self.text = text
    self.symbol = symbol
    self.tint = tint
    self.accessory = accessory()
  }

  public var body: some View {
    HStack(alignment: .top, spacing: 12) {
      if let symbol {
        Image(systemName: symbol)
          .font(.system(size: 17, weight: .medium))
          .foregroundStyle(tint)
          .frame(width: 20, height: 20)
          .accessibilityHidden(true)
      }
      VStack(alignment: .leading, spacing: 8) {
        Text(text).tollType(.note, TollColor.label).fixedSize(horizontal: false, vertical: true)
        accessory
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, TollSpacing.noteCardVertical)
    .padding(.horizontal, TollSpacing.cardPadding)
    .background(
      TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }
}

extension NoteCard where Accessory == EmptyView {
  public init(_ text: String, symbol: String? = nil, tint: Color = TollColor.label2) {
    self.init(text, symbol: symbol, tint: tint) { EmptyView() }
  }
}

/// A quiet line under a card or a title: 13/18 in `label2`, inset 4 pt as the boards do.
public struct Footnote: View {
  let text: String
  let symbol: String?
  let alignment: TextAlignment

  public init(_ text: String, symbol: String? = nil, alignment: TextAlignment = .leading) {
    self.text = text
    self.symbol = symbol
    self.alignment = alignment
  }

  public var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      if let symbol {
        Image(systemName: symbol).accessibilityHidden(true)
      }
      Text(text)
        .multilineTextAlignment(alignment)
        .fixedSize(horizontal: false, vertical: true)
    }
    .tollType(.detail, TollColor.label2)
    .padding(.horizontal, 4)
    .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
  }
}

/// A section's header: an eyebrow and, at the right, an optional action ("See all", "New").
public struct SectionHeader: View {
  let title: String
  let action: (title: String, run: () -> Void)?

  public init(_ title: String, action: (title: String, run: () -> Void)? = nil) {
    self.title = title
    self.action = action
  }

  public var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .tollType(.eyebrow, TollColor.label2)
        .accessibilityAddTraits(.isHeader)
      Spacer(minLength: 12)
      if let action {
        Button(action.title, action: action.run)
          .tollType(.action, TollColor.accent)
          .frame(minHeight: TollSpacing.minTapTarget)
          .padding(.vertical, -14)
      }
    }
  }
}
