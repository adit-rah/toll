import SwiftUI

/// A row for something iOS names and draws itself (`Label(token)` from FamilyControls): its icon in
/// the canvas's 32 pt square with 8 pt corners, its name as a row title, and an optional detail
/// ("Whole category", "Website"). The app never sees the name; this only places what iOS draws.
public struct AppRowLabelStyle: LabelStyle {
  let detail: String?

  public init(detail: String? = nil) {
    self.detail = detail
  }

  public func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: TollSpacing.rowGap) {
      configuration.icon
        .font(.system(size: 26))
        .frame(width: TileSize.small.side, height: TileSize.small.side)
        .background(TollColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: TileSize.small.radius, style: .continuous))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 1) {
        configuration.title
          .tollType(.rowTitle, TollColor.label)
          .lineLimit(2)
        if let detail {
          Text(detail).tollType(.detail, TollColor.label2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 8)
    .frame(minHeight: detail == nil ? RowSize.compact.minHeight : RowSize.category.minHeight)
  }
}

/// "Choose more": a plus in the tile's column, the words in the accent.
public struct ChooseMoreRow: View {
  let title: String
  let action: () -> Void

  public init(_ title: String, action: @escaping () -> Void) {
    self.title = title
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: TollSpacing.rowGap) {
        Image(systemName: "plus")
          .font(.system(size: 18, weight: .semibold))
          .frame(width: TileSize.small.side)
          .accessibilityHidden(true)
        Text(title).tollType(.rowTitle)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .foregroundStyle(TollColor.accent)
      .frame(minHeight: RowSize.compact.minHeight)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
