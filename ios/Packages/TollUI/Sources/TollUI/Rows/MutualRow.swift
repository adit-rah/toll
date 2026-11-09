import SwiftUI

/// Design §3.6. Never a count, never tags: a mutual is someone you might add, not someone to compare
/// against yet.
public struct MutualRow: View {
  let name: String
  let handle: String
  let photoURL: URL?
  let status: StatusMark?
  let detail: String
  let trend: Trend?
  let addTitle: String
  let onAdd: () -> Void
  let statusSpeech: String?
  let trendSpeech: String?
  let separatorAbove: Bool

  /// `detail` is the mutual line ("friends with Adi and 2 others"); the speech strings follow
  /// `FriendRow.Speech`.
  public init(
    name: String, handle: String, photoURL: URL? = nil, status: StatusMark?, detail: String,
    trend: Trend?, addTitle: String, statusSpeech: String? = nil, trendSpeech: String? = nil,
    separatorAbove: Bool = true, onAdd: @escaping () -> Void
  ) {
    self.name = name
    self.handle = handle
    self.photoURL = photoURL
    self.status = status
    self.detail = detail
    self.trend = trend
    self.addTitle = addTitle
    self.onAdd = onAdd
    self.statusSpeech = statusSpeech
    self.trendSpeech = trendSpeech
    self.separatorAbove = separatorAbove
  }

  public var body: some View {
    RowStack(minHeight: TollSpacing.friendRowMinHeight) {
      HStack(spacing: TollSpacing.rowLeadingGap) {
        Avatar(name: name, handle: handle, photoURL: photoURL, size: .row, status: status)
        VStack(alignment: .leading, spacing: 2) {
          Text(name).font(TollFont.headline).foregroundStyle(TollColor.label).lineLimit(1)
          Text(detail).tollText(.subhead).lineLimit(2)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        AccessibilitySentence.join([name, statusSpeech, detail, trendSpeech]))
    } trailing: {
      HStack(spacing: 12) {
        if let trend {
          TrendLabel(trend).accessibilityHidden(true)
        }
        QuietButton(addTitle, action: onAdd)
      }
    }
    .overlay(alignment: .top) {
      if separatorAbove {
        Hairline()
      }
    }
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
