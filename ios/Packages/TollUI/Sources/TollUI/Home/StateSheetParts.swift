import SwiftUI
import TollCore

/// The top of the bar's sheet (design §3.18): the bar's icon, a 20 pt title and one line.
public struct SheetHeader<Icon: View, Title: View>: View {
  let line: String?
  let icon: Icon
  let title: Title

  public init(line: String?, @ViewBuilder icon: () -> Icon, @ViewBuilder title: () -> Title) {
    self.line = line
    self.icon = icon()
    self.title = title()
  }

  public var body: some View {
    HStack(spacing: TollSpacing.rowLeadingGap) {
      icon
      VStack(alignment: .leading, spacing: 2) {
        title
          .font(TollFont.sheetTitle)
          .foregroundStyle(TollColor.label)
        if let line {
          Text(line).tollText(.caption).monospacedDigit()
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }
}

/// A card on the sheet: `surfaceRaised` on the sheet's `bg` (design §2.1), radius 16.
public struct SheetCard<Content: View>: View {
  let padding: EdgeInsets
  let content: Content

  public init(
    padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
    @ViewBuilder content: () -> Content
  ) {
    self.padding = padding
    self.content = content()
  }

  public var body: some View {
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        TollColor.surfaceRaised,
        in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }
}

/// How much of a session has gone, as a 6 pt line that fills left to right. It owns its tick.
public struct SessionProgress: View {
  let startedAt: Date
  let endsAt: Date
  let total: String

  public init(startedAt: Date, endsAt: Date, total: String) {
    self.startedAt = startedAt
    self.endsAt = endsAt
    self.total = total
  }

  public var body: some View {
    TimelineView(.periodic(from: endsAt.addingTimeInterval(-WaitClock.anchorLead), by: 1)) {
      context in
      let span = max(1, endsAt.timeIntervalSince(startedAt))
      let gone = min(1, max(0, context.date.timeIntervalSince(startedAt) / span))
      let left = WaitClock.secondsLeft(until: endsAt, at: context.date)
      VStack(spacing: 8) {
        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            Capsule().fill(TollColor.fill)
            Capsule().fill(TollColor.accent).frame(width: proxy.size.width * gone)
          }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
        HStack {
          Text(Copy.ActiveBlock.left(seconds: left))
            .accessibilityLabel(WaitClock.spoken(step: WaitClock.spokenStep(left)))
          Spacer(minLength: 8)
          Text(total)
        }
        .tollText(.caption)
        .monospacedDigit()
      }
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.updatesFrequently)
    }
  }
}
