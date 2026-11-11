import SwiftUI

/// Design §3.6. Never a count, never tags: a mutual is someone you might add, not someone to compare
/// against yet. School members use the same row with their handle as the detail.
public struct MutualRow: View {
  public enum Trailing {
    case add(title: String, action: () -> Void)
    /// A request already sent: the word alone, so it cannot be sent twice.
    case note(String)
    case nothing
  }

  let name: String
  let handle: String
  let photoURL: URL?
  let status: StatusMark?
  let detail: String
  let trend: Trend?
  let trailing: Trailing
  let statusSpeech: String?
  let trendSpeech: String?
  let separatorAbove: Bool
  let backing: Color
  @Environment(\.dynamicTypeSize) private var typeSize

  /// `detail` is the mutual line ("friends with Adi and 2 others"); the speech strings follow
  /// `FriendRow.Speech`; `backing` is the colour under the row (see `Avatar`).
  public init(
    name: String, handle: String, photoURL: URL? = nil, status: StatusMark?, detail: String,
    trend: Trend? = nil, trailing: Trailing, statusSpeech: String? = nil,
    trendSpeech: String? = nil, separatorAbove: Bool = true, backing: Color = TollColor.bg
  ) {
    self.name = name
    self.handle = handle
    self.photoURL = photoURL
    self.status = status
    self.detail = detail
    self.trend = trend
    self.trailing = trailing
    self.statusSpeech = statusSpeech
    self.trendSpeech = trendSpeech
    self.separatorAbove = separatorAbove
    self.backing = backing
  }

  public var body: some View {
    PersonRowLayout(
      avatar: Avatar(
        name: name, handle: handle, photoURL: photoURL, size: .row, status: status,
        backing: backing),
      stacked: typeSize.isAccessibilitySize
    ) {
      VStack(alignment: .leading, spacing: 2) {
        // The trend rides beside the name so the trailing column is the action alone and the mutual
        // line keeps the row's width.
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(name).font(TollFont.headline).foregroundStyle(TollColor.label)
          if let trend {
            TrendLabel(trend).fixedSize()
          }
        }
        .lineLimit(1)
        Text(detail).tollText(.subhead).lineLimit(2)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        AccessibilitySentence.join([name, statusSpeech, detail, trendSpeech, note]))
    } trailing: {
      switch trailing {
      case .add(let title, let action):
        QuietButton(title, action: action)
          .accessibilityLabel(AccessibilitySentence.join([title, name]))
      case .note(let text):
        Text(text)
          .tollText(.subhead)
          .frame(minHeight: TollSpacing.minTapTarget)
          .accessibilityHidden(true)
      case .nothing:
        EmptyView()
      }
    }
    .overlay(alignment: .top) {
      if separatorAbove {
        Hairline()
      }
    }
  }

  private var note: String? {
    if case .note(let text) = trailing { return text }
    return nil
  }
}

/// The Home section header: an uppercase label ("FRIENDS") with an optional trailing caption.
public struct SectionHeader: View {
  let title: String
  let trailing: String?

  public init(_ title: String, trailing: String? = nil) {
    self.title = title
    self.trailing = trailing
  }

  public var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline) {
        titleText
        Spacer(minLength: 12)
        trailingText
      }
      VStack(alignment: .leading, spacing: 4) {
        titleText
        trailingText
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }

  private var titleText: some View {
    Text(title)
      .textCase(.uppercase)
      .font(TollFont.captionMedium)
      .foregroundStyle(TollColor.label2)
  }

  @ViewBuilder
  private var trailingText: some View {
    if let trailing {
      Text(trailing).tollText(.caption).monospacedDigit()
    }
  }
}
