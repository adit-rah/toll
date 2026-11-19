import SwiftUI

/// The canvas's grouped card: `surface`, 18 pt corners, rows separated by hairlines. Views only; the
/// rows bring their own text from `Copy`.
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

/// A rounded square holding one SF Symbol: amber on soft amber when it leads, gray when it doesn't.
public struct IconTile: View {
  let symbol: String
  let size: CGFloat
  let isAccent: Bool
  @ScaledMetric private var scale: CGFloat = 1

  public init(_ symbol: String, size: CGFloat = 36, accent: Bool = true) {
    self.symbol = symbol
    self.size = size
    self.isAccent = accent
  }

  public var body: some View {
    Image(systemName: symbol)
      .font(.system(size: size * 0.5, weight: .medium))
      .foregroundStyle(isAccent ? TollColor.accent : TollColor.label2)
      .frame(width: size * min(scale, 1.6), height: size * min(scale, 1.6))
      .background(
        isAccent ? TollColor.accentSoft : TollColor.surfaceRaised,
        in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
      )
      .accessibilityHidden(true)
  }
}

/// A card row: an optional leading tile, a title, an optional detail, an optional trailing view. At
/// accessibility sizes the trailing view moves under the text rather than squeezing it.
public struct CardRow<Leading: View, Trailing: View>: View {
  let title: String
  let detail: String?
  let leading: Leading
  let trailing: Trailing
  @Environment(\.dynamicTypeSize) private var typeSize

  public init(
    _ title: String, detail: String? = nil, @ViewBuilder leading: () -> Leading,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.title = title
    self.detail = detail
    self.leading = leading()
    self.trailing = trailing()
  }

  public var body: some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: TollSpacing.labelGap))
      : AnyLayout(HStackLayout(spacing: 14))
    layout {
      HStack(spacing: 14) {
        leading
        VStack(alignment: .leading, spacing: 1) {
          Text(title).font(TollFont.bodyMedium).foregroundStyle(TollColor.label)
          if let detail {
            Text(detail).font(TollFont.caption).foregroundStyle(TollColor.label2).monospacedDigit()
          }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      trailing
    }
    .frame(minHeight: 60)
    .padding(.vertical, 6)
  }
}

extension CardRow where Trailing == EmptyView {
  public init(_ title: String, detail: String? = nil, @ViewBuilder leading: () -> Leading) {
    self.init(title, detail: detail, leading: leading) { EmptyView() }
  }
}

/// A quiet line under a card or a title: `caption` in `label2`, optionally led by a symbol.
public struct Footnote: View {
  let text: String
  let symbol: String?

  public init(_ text: String, symbol: String? = nil) {
    self.text = text
    self.symbol = symbol
  }

  public var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      if let symbol {
        Image(systemName: symbol).foregroundStyle(TollColor.label2).accessibilityHidden(true)
      }
      Text(text).fixedSize(horizontal: false, vertical: true)
    }
    .font(TollFont.caption)
    .foregroundStyle(TollColor.label2)
    .padding(.horizontal, 4)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
