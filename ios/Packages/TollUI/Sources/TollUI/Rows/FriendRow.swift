import SwiftUI

/// Design §3.4. Tap and the long-press menu belong to the caller; wrap the row in a `Button` or add
/// `.contextMenu` outside it.
public struct FriendRow: View {
  public enum Trailing {
    /// Today's count with the week trend beneath; a nil trend shows nothing.
    case count(Int, trend: Trend?)
    /// Toll is off on their phone: "—" in `label3`.
    case silent
    /// The People roster, where the week is the detail line and only its trend trails.
    case trend(Trend?)
    /// A pending request: Accept and Decline as quiet buttons.
    case request(
      acceptTitle: String, declineTitle: String, onAccept: () -> Void, onDecline: () -> Void)
  }

  public enum DetailStyle: Sendable {
    /// Home: 12 pt and cut early, so a long sentence never crowds the count.
    case compact
    /// People: `subhead`, as wide as the row allows.
    case regular
  }

  /// The spoken pieces, in reading order after the name. Each is optional; strings come from `Copy`
  /// or the caller.
  public struct Speech: Sendable {
    public var status: String?
    public var count: String?
    public var trend: String?

    public init(status: String? = nil, count: String? = nil, trend: String? = nil) {
      self.status = status
      self.count = count
      self.trend = trend
    }
  }

  let name: String
  let handle: String
  let handleCaption: String?
  let photoURL: URL?
  let status: StatusMark?
  let detail: String
  let detailStyle: DetailStyle
  let trailing: Trailing
  let speech: Speech
  let separatorAbove: Bool
  let backing: Color
  @Environment(\.dynamicTypeSize) private var typeSize

  /// `backing` is the colour under the row (see `Avatar`).
  public init(
    name: String, handle: String, handleCaption: String? = nil, photoURL: URL? = nil,
    status: StatusMark?, detail: String, detailStyle: DetailStyle = .compact, trailing: Trailing,
    speech: Speech, separatorAbove: Bool = true, backing: Color = TollColor.bg
  ) {
    self.name = name
    self.handle = handle
    self.handleCaption = handleCaption
    self.photoURL = photoURL
    self.status = status
    self.detail = detail
    self.detailStyle = detailStyle
    self.trailing = trailing
    self.speech = speech
    self.separatorAbove = separatorAbove
    self.backing = backing
  }

  public var body: some View {
    PersonRowLayout(
      avatar: Avatar(
        name: name, handle: handle, photoURL: photoURL, size: .row, status: status,
        backing: backing),
      stacked: stacked
    ) {
      label
    } trailing: {
      trailingView
    }
    .overlay(alignment: .top) {
      if separatorAbove {
        Hairline()
      }
    }
  }

  // Two buttons leave the name too little room well before the accessibility sizes.
  private var stacked: Bool {
    if typeSize.isAccessibilitySize { return true }
    if case .request = trailing { return typeSize >= .xxLarge }
    return false
  }

  private var label: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(name).font(TollFont.headline).foregroundStyle(TollColor.label).layoutPriority(1)
        if let handleCaption {
          Text(handleCaption).tollText(.caption)
        }
      }
      .lineLimit(1)
      switch detailStyle {
      case .compact:
        DetailLine(detail)
      case .regular:
        Text(detail).tollText(.subhead).monospacedDigit().lineLimit(2)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(sentence)
  }

  @ViewBuilder
  private var trailingView: some View {
    switch trailing {
    case .count(let count, let trend):
      // Beneath the name the pair reads along one line; in its own column it stacks, right-aligned.
      let layout =
        stacked
        ? AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        : AnyLayout(VStackLayout(alignment: .trailing, spacing: 2))
      layout {
        Text(verbatim: "\(count)").font(TollFont.number).foregroundStyle(TollColor.label)
        if let trend {
          TrendLabel(trend)
        }
      }
      .accessibilityHidden(true)
    case .silent:
      Text(verbatim: "—")
        .font(TollFont.number)
        .foregroundStyle(TollColor.label3)
        .accessibilityHidden(true)
    case .trend(let trend):
      if let trend {
        TrendLabel(trend).accessibilityHidden(true)
      }
    case .request(let acceptTitle, let declineTitle, let onAccept, let onDecline):
      HStack(spacing: 16) {
        QuietButton(acceptTitle, action: onAccept)
          .accessibilityLabel(AccessibilitySentence.join([acceptTitle, name]))
        QuietButton(declineTitle, tone: .secondary, action: onDecline)
          .accessibilityLabel(AccessibilitySentence.join([declineTitle, name]))
      }
    }
  }

  private var sentence: String {
    switch trailing {
    case .count:
      return AccessibilitySentence.join([name, speech.status, speech.count, speech.trend])
    case .trend:
      return AccessibilitySentence.join([name, speech.status, detail, speech.trend])
    case .silent, .request:
      return AccessibilitySentence.join([name, speech.status, detail])
    }
  }
}

/// The geometry `FriendRow` and `MutualRow` share: avatar, a text column, a trailing column that keeps
/// its width so a number is never the thing that truncates. When `stacked` (accessibility sizes,
/// design §5) the trailing content drops beneath the text, on the text's leading edge.
struct PersonRowLayout<Label: View, Trailing: View>: View {
  let avatar: Avatar
  let stacked: Bool
  let label: Label
  let trailing: Trailing

  init(
    avatar: Avatar, stacked: Bool, @ViewBuilder label: () -> Label,
    @ViewBuilder trailing: () -> Trailing
  ) {
    self.avatar = avatar
    self.stacked = stacked
    self.label = label()
    self.trailing = trailing()
  }

  var body: some View {
    HStack(alignment: stacked ? .top : .center, spacing: TollSpacing.rowLeadingGap) {
      avatar
      if stacked {
        VStack(alignment: .leading, spacing: 4) {
          label
          trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        label.frame(maxWidth: .infinity, alignment: .leading)
        trailing.fixedSize()
      }
    }
    .padding(.vertical, stacked ? 10 : 8)
    .frame(maxWidth: .infinity, minHeight: TollSpacing.friendRowMinHeight, alignment: .leading)
    .contentShape(Rectangle())
  }
}

/// The 12 pt detail line, cut early at standard sizes so it never crowds the trailing column.
struct DetailLine: View {
  let text: String
  @Environment(\.dynamicTypeSize) private var typeSize

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .font(TollFont.detail)
      .foregroundStyle(TollColor.label2)
      .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
      .truncationMode(.tail)
      .frame(maxWidth: typeSize.isAccessibilitySize ? nil : 200, alignment: .leading)
  }
}
