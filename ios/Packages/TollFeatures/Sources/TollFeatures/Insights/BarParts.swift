import SwiftUI
import TollCore
import TollUI

/// Day by day (I-2): each weekday's bar from last week beside this week's. Drawn by hand because a
/// Swift Charts bar cannot be outlined, and today's is: the day is not over.
struct DayPairBars: View {
  struct Pair: Identifiable {
    var id: Int
    var label: String
    var last: DayMetrics
    var this: DayMetrics
  }

  let pairs: [Pair]
  let today: TollDay?
  var selected: TollDay? = nil
  var height: CGFloat = ChartHeight.bars
  var onSelect: ((TollDay) -> Void)? = nil

  private static let stub: CGFloat = 2
  private static let pairGap: CGFloat = 3
  private static let groupGap: CGFloat = 6

  /// Fourteen days, last Monday first, as seven weekday pairs. Anything else draws nothing.
  static func weekdayPairs(_ days: [DayMetrics]) -> [Pair] {
    guard days.count == 14 else { return [] }
    return (0..<7).map { index in
      Pair(id: index, label: ChartLabels.weekday(days[index].day.weekday), last: days[index], this: days[index + 7])
    }
  }

  var body: some View {
    let top = max(1, pairs.map { max($0.last.passes, $0.this.passes) }.max() ?? 1)
    VStack(spacing: 6) {
      GeometryReader { proxy in
        HStack(alignment: .bottom, spacing: Self.groupGap) {
          ForEach(pairs) { pair in
            HStack(alignment: .bottom, spacing: Self.pairGap) {
              bar(pair.last, isThisWeek: false, top: top, plot: proxy.size.height)
              bar(pair.this, isThisWeek: true, top: top, plot: proxy.size.height)
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      }
      HStack(spacing: Self.groupGap) {
        ForEach(pairs) { pair in
          // Today is heavier as well as accented, so it is not marked by colour alone.
          Text(pair.label)
            .font(TollFont.micro)
            .fontWeight(pair.this.day == today ? .bold : .medium)
            .foregroundStyle(pair.this.day == today ? TollColor.accent : TollColor.label3)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
        }
      }
      // Seven labels share the card's width; past this size they would be ellipses, not weekdays.
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    .frame(height: height)
    .overlay {
      if let onSelect {
        // Full-height columns: a 2 pt stub is as easy to hit as the tallest bar (design §5).
        HStack(spacing: 0) {
          ForEach(pairs) { pair in
            Color.clear.contentShape(Rectangle()).onTapGesture { onSelect(pair.last.day) }
            Color.clear.contentShape(Rectangle()).onTapGesture { onSelect(pair.this.day) }
          }
        }
      }
    }
  }

  @ViewBuilder
  private func bar(_ day: DayMetrics, isThisWeek: Bool, top: Int, plot: CGFloat) -> some View {
    let shape = UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3)
    let filled = max(Self.stub, plot * CGFloat(day.passes) / CGFloat(top))
    let isToday = isThisWeek && day.day == today
    let isAhead = today.map { day.day > $0 } ?? false
    Group {
      if isAhead {
        // A day that has not happened is not a clean day; it gets no stub.
        Color.clear
      } else if isToday && day.passes > 0 {
        shape.strokeBorder(TollColor.accent, lineWidth: 1.5)
      } else {
        shape.fill(isThisWeek ? TollColor.accent : TollColor.neutralBar)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: day.passes > 0 ? filled : Self.stub)
    .opacity(selected != nil && selected != day.day ? 0.35 : 1)
  }
}

/// Rows of name, bar and value (I-5, I-11). Each bar sits on a track so a short one still reads as
/// part of a whole, and the value is always written out beside it.
struct ValueBars: View {
  struct Row: Identifiable {
    var id: String
    var name: String
    var fraction: Double
    var value: String
    var isMine = false
  }

  let rows: [Row]
  let title: String
  @Environment(\.dynamicTypeSize) private var typeSize

  private static let nameWidth: CGFloat = 96
  private static let barHeight: CGFloat = 8

  var body: some View {
    Group {
      if typeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(rows) { row in
            VStack(alignment: .leading, spacing: 4) {
              name(row)
              track(row)
              value(row)
            }
          }
        }
      } else {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
          ForEach(rows) { row in
            GridRow {
              name(row).lineLimit(1).frame(maxWidth: Self.nameWidth, alignment: .leading)
              track(row)
              value(row).lineLimit(1).gridColumnAlignment(.trailing)
            }
          }
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityValue(AccessibilitySentence.join(rows.map { "\($0.name) \($0.value)" }))
    .audioGraph(title, labels: rows.map(\.name), values: rows.map { $0.fraction * 100 })
  }

  private func name(_ row: Row) -> some View {
    Text(row.name)
      .font(row.isMine ? TollFont.captionMedium : TollFont.caption)
      .foregroundStyle(row.isMine ? TollColor.label : TollColor.label2)
  }

  private func value(_ row: Row) -> some View {
    Text(row.value).font(TollFont.captionNumber).foregroundStyle(TollColor.label)
  }

  private func track(_ row: Row) -> some View {
    let fraction = CGFloat(min(1, max(0, row.fraction)))
    return Capsule()
      .fill(TollColor.surfaceRaised)
      .frame(height: Self.barHeight)
      .frame(maxWidth: .infinity)
      .overlay(alignment: .leading) {
        GeometryReader { proxy in
          Capsule()
            .fill(row.isMine ? TollColor.accent : TollColor.neutralBar)
            // Never narrower than it is tall, so the smallest share is still a dot, not a sliver.
            .frame(width: fraction > 0 ? max(Self.barHeight, proxy.size.width * fraction) : 0)
        }
      }
  }
}

/// What the school blocks (I-18): one bar split by share, largest first, in the sequential ramp, so
/// the order reads without matching colours to a legend. Names and numbers sit beneath.
struct ShareBar: View {
  struct Segment: Identifiable {
    var id: String
    var name: String
    var percent: Int
    var rank: Int
  }

  let segments: [Segment]
  let title: String

  private static let barHeight: CGFloat = 12
  private static let gap: CGFloat = 2

  var body: some View {
    let total = CGFloat(max(1, segments.reduce(0) { $0 + $1.percent }))
    VStack(alignment: .leading, spacing: 12) {
      GeometryReader { proxy in
        let width = max(0, proxy.size.width - Self.gap * CGFloat(max(0, segments.count - 1)))
        HStack(spacing: Self.gap) {
          ForEach(segments) { segment in
            Rectangle()
              .fill(colour(segment.rank))
              .frame(width: width * CGFloat(segment.percent) / total)
          }
        }
      }
      .frame(height: Self.barHeight)
      .clipShape(Capsule())
      FlowLayout(spacing: 12, lineSpacing: 6, centred: false) {
        ForEach(segments) { segment in
          HStack(spacing: 6) {
            Circle().fill(colour(segment.rank)).frame(width: 8, height: 8)
            Text(segment.name).font(TollFont.caption).foregroundStyle(TollColor.label2)
            Text(Copy.percent(segment.percent)).font(TollFont.captionNumber).foregroundStyle(TollColor.label)
          }
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityValue(AccessibilitySentence.join(segments.map { "\($0.name) \(Copy.percent($0.percent))" }))
    .audioGraph(title, labels: segments.map(\.name), values: segments.map { Double($0.percent) })
  }

  private func colour(_ rank: Int) -> Color {
    TollColor.heat[min(TollColor.heat.count - 1, max(0, TollColor.heat.count - 1 - rank))]
  }
}

/// A row of `MetricPair`s (design §3.3) that drops to two columns when one row does not fit, as on
/// a narrow phone or at large text sizes.
struct MetricStrip: View {
  struct Item: Identifiable {
    var label: String
    var value: String
    var previous: String? = nil
    var id: String { label }
  }

  let items: [Item]

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 0) {
        ForEach(items) { item in
          if item.id != items.first?.id { Spacer(minLength: 12) }
          MetricPair(label: item.label, value: item.value, previous: item.previous)
        }
      }
      Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 12) {
        ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { index in
          GridRow {
            cell(items[index])
            if index + 1 < items.count { cell(items[index + 1]) }
          }
        }
      }
      // The largest Dynamic Type sizes: two columns cut values to "4…" (AX5 render, ledger A125).
      VStack(alignment: .leading, spacing: 12) {
        ForEach(items) { item in cell(item) }
      }
    }
  }

  private func cell(_ item: Item) -> some View {
    MetricPair(label: item.label, value: item.value, previous: item.previous)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
