import SwiftUI
import TollCore

public enum BlockRowStyle: Sendable {
  /// 64 pt: names on one line, the schedule beneath.
  case regular
  /// 48 pt, for finished blocks above the setup creator: "names · schedule" on one line.
  case compact
}

/// Design §3.10. The icons and names are view slots because they are system `Label(token)` views; use
/// `IconCluster` for the icons. Tap and swipe actions belong to the caller.
public struct BlockRow<Icons: View, Names: View>: View {
  let schedule: String
  let style: BlockRowStyle
  let icons: Icons
  let names: Names

  /// `schedule` is `Copy.Schedules.label(_:)`.
  public init(
    schedule: String, style: BlockRowStyle = .regular, @ViewBuilder icons: () -> Icons,
    @ViewBuilder names: () -> Names
  ) {
    self.schedule = schedule
    self.style = style
    self.icons = icons()
    self.names = names()
  }

  public var body: some View {
    HStack(spacing: TollSpacing.rowLeadingGap) {
      icons
      Group {
        switch style {
        case .regular:
          VStack(alignment: .leading, spacing: 2) {
            names
              .font(TollFont.body)
              .foregroundStyle(TollColor.label)
              .lineLimit(1)
            Text(schedule).tollText(.caption).monospacedDigit()
          }
        case .compact:
          HStack(spacing: 0) {
            names
              .font(TollFont.body)
              .foregroundStyle(TollColor.label)
              .lineLimit(1)
            Text(Copy.middleDot + schedule)
              .font(TollFont.body)
              .foregroundStyle(TollColor.label2)
              .lineLimit(1)
              .layoutPriority(1)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Image(systemName: "chevron.right")
        .font(TollFont.captionMedium)
        .foregroundStyle(TollColor.label3)
        .accessibilityHidden(true)
    }
    .frame(
      minHeight: style == .regular ? TollSpacing.blockRowHeight : TollSpacing.compactBlockRowHeight
    )
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }
}

/// Up to three 28 pt app icons overlapping by 6 pt.
public struct IconCluster<Content: View>: View {
  let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    HStack(spacing: -6) {
      // Group so the frame applies to each icon, not to the cluster.
      Group { content }
        .frame(width: 28, height: 28)
    }
  }
}
