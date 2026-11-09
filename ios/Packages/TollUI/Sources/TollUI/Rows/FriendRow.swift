import SwiftUI

/// Design §3.4. Tap and the long-press menu belong to the caller; wrap the row in a `Button` or add
/// `.contextMenu` outside it.
public struct FriendRow: View {
  public enum Trailing {
    /// Today's count with the week trend beneath; a nil trend shows nothing.
    case count(Int, trend: Trend?)
    /// Toll is off on their phone: "—" in `label3`.
    case silent
    /// A pending request: Accept and Decline as quiet buttons.
    case request(
      acceptTitle: String, declineTitle: String, onAccept: () -> Void, onDecline: () -> Void)
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
  let trailing: Trailing
  let speech: Speech
  let separatorAbove: Bool

  public init(
    name: String, handle: String, handleCaption: String? = nil, photoURL: URL? = nil,
    status: StatusMark?, detail: String, trailing: Trailing, speech: Speech,
    separatorAbove: Bool = true
  ) {
    self.name = name
    self.handle = handle
    self.handleCaption = handleCaption
    self.photoURL = photoURL
    self.status = status
    self.detail = detail
    self.trailing = trailing
    self.speech = speech
    self.separatorAbove = separatorAbove
  }

  public var body: some View {
    RowStack(minHeight: TollSpacing.friendRowMinHeight) {
      info
    } trailing: {
      trailingView
    }
    .overlay(alignment: .top) {
      if separatorAbove {
        Hairline()
      }
    }
  }

  private var info: some View {
    HStack(spacing: TollSpacing.rowLeadingGap) {
      Avatar(name: name, handle: handle, photoURL: photoURL, size: .row, status: status)
      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(name).font(TollFont.headline).foregroundStyle(TollColor.label)
          if let handleCaption {
            Text(handleCaption).tollText(.caption)
          }
        }
        .lineLimit(1)
        DetailLine(detail)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(sentence)
  }

  @ViewBuilder
  private var trailingView: some View {
    switch trailing {
    case .count(let count, let trend):
      VStack(alignment: .trailing, spacing: 2) {
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
    case .request(let acceptTitle, let declineTitle, let onAccept, let onDecline):
      HStack(spacing: 16) {
        QuietButton(declineTitle, tone: .secondary, action: onDecline)
        QuietButton(acceptTitle, action: onAccept)
      }
    }
  }

  private var sentence: String {
    let includesDetail: Bool
    switch trailing {
    case .count: includesDetail = false
    case .silent, .request: includesDetail = true
    }
    return AccessibilitySentence.join([
      name, speech.status, speech.count, speech.trend, includesDetail ? detail : nil,
    ])
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
