import SwiftUI
import TollCore
import TollUI

/// "Turn it back on · $9.99 once · every night after": the one card after the trial (D33).
struct PausedCard: View {
  let price: String
  let open: () -> Void

  var body: some View {
    Button(action: open) {
      Card {
        CardRow(
          Copy.Home.turnBackOn, detail: Copy.Home.onceEveryNight(price),
          size: RowSize(minHeight: 68, tile: .large)
        ) {
          IconTile("moon", size: .large)
        } trailing: {
          Chevron()
        }
      }
    }
    .buttonStyle(.plain)
  }
}

/// Tonight on a 6 pm → 10 am strip (the canvas): an 8 pt track, the block solid while on, outlined
/// before, dashed after the trial; a 2 pt line for now, with "Now" over it inside the strip.
struct TimelineStrip: View {
  let timeline: HomeSnapshot.Timeline

  var body: some View {
    VStack(spacing: 10) {
      GeometryReader { proxy in
        let width = proxy.size.width
        ZStack(alignment: .topLeading) {
          RoundedRectangle(cornerRadius: 4).fill(TollColor.surfaceRaised).frame(height: 8)
          block
            .frame(width: max(8, width * (timeline.end - timeline.start)), height: 8)
            .offset(x: width * timeline.start)
          if let now = timeline.now {
            RoundedRectangle(cornerRadius: 1)
              .fill(TollColor.label)
              .frame(width: 2, height: 20)
              .offset(x: width * now - 1, y: -6)
            if timeline.nowInside {
              Text(Copy.Home.now)
                .tollType(TollType(size: 11, lineHeight: 14, weight: .semibold, style: .caption2))
                .foregroundStyle(TollColor.label)
                .fixedSize()
                .alignmentGuide(.leading) { $0.width / 2 }
                .offset(x: min(max(width * now, 14), width - 14), y: -24)
            }
          }
        }
      }
      .frame(height: 8)
      .padding(.top, 26)
      HourLabels()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(timeline.label)
  }

  @ViewBuilder private var block: some View {
    let shape = RoundedRectangle(cornerRadius: 4)
    switch timeline.phase {
    case .on: shape.fill(TollColor.accent)
    case .upcoming: shape.fill(TollColor.accentSoft).overlay(shape.stroke(TollColor.accent))
    case .paused:
      shape.stroke(TollColor.label3, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
    }
  }
}

/// "6 pm  10 pm  2 am  6 am  10 am" every four hours across the strip, the ends held to its edges,
/// in the phone's format.
private struct HourLabels: View {
  var body: some View {
    let hours = [18, 22, 2, 6, 10].map { Copy.time(ClockTime(hour: $0), short: true) }
    GeometryReader { proxy in
      let width = proxy.size.width
      ZStack {
        ForEach(hours.indices, id: \.self) { index in
          let label = Text(hours[index]).fixedSize()
          if index == 0 {
            label.frame(maxWidth: .infinity, alignment: .leading)
          } else if index == hours.count - 1 {
            label.frame(maxWidth: .infinity, alignment: .trailing)
          } else {
            label.position(x: width * CGFloat(index) / CGFloat(hours.count - 1), y: 7)
          }
        }
      }
      .frame(width: width, height: 14)
    }
    .frame(height: 14)
    .tollType(.micro, TollColor.label2)
  }
}

/// This week: three numbers (the third is Apple's Screen Time tile, once its report extension is
/// in), then the nights. Before three nights, the slots and one line instead of the chart.
struct WeekCard: View {
  let home: HomeSnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if home.showsTrends {
        // Three equal columns, as the board: the third is kept for Apple's tile.
        HStack(alignment: .top, spacing: 12) {
          Stat(
            value: Copy.Home.nightsBlocked(
              home.nightsBlocked, of: max(home.nightsCounted, home.nightsBlocked)),
            label: Copy.Home.nightsBlockedLabel)
          Stat(
            value: "\(home.timesStopped)", label: Copy.Home.stoppedLabel,
            change: home.stopsChange)
          Color.clear.frame(maxWidth: .infinity, maxHeight: 1).accessibilityHidden(true)
        }
        Text(Copy.Home.byNight)
          .tollType(.microEyebrow, TollColor.label2)
          .padding(.top, 22)
        NightBars(bars: home.bars).padding(.top, 6)
      } else {
        FirstNights(bars: home.bars)
        Text(Copy.Home.nightsSoFar(home.nightsBlocked))
          .tollType(.link, TollColor.label)
          .padding(.top, 16)
        Text(Copy.Home.trendsLater)
          .tollType(TollType(size: 14, lineHeight: 20, weight: .regular, style: .subheadline))
          .foregroundStyle(TollColor.label2)
          .padding(.top, 2)
      }
    }
    .padding(.vertical, TollSpacing.statsCardVertical)
    .padding(.horizontal, TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }
}

/// A number and what it counts; the change since the week before beside it once there is one.
struct Stat: View {
  let value: String
  let label: String
  var change: Int?

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(value).tollType(.stat, TollColor.label)
        if let change, change != 0 {
          Text(Copy.Home.change(change))
            .tollType(.trailing, change < 0 ? TollColor.ok : TollColor.label2)
            .accessibilityLabel(Copy.Home.changeSpoken(change))
        }
      }
      Text(label).tollType(.caption, TollColor.label2).fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// Times the block stopped you, one bar per night: tallest 64 pt, a 0 as a 3 pt sliver, a night
/// with no block as a dash, nights to come as dashed outlines; tonight in amber.
struct NightBars: View {
  let bars: [HomeSnapshot.Bar]

  var body: some View {
    let top = max(1, bars.map(\.count).max() ?? 1)
    HStack(alignment: .bottom, spacing: 8) {
      ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
        VStack(spacing: 0) {
          value(bar)
          shape(bar, top: top)
          Text(bar.day)
            .tollType(.micro, bar.isToday ? TollColor.label : TollColor.label2)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(bar))
      }
    }
    .frame(height: 104, alignment: .bottom)
  }

  @ViewBuilder private func value(_ bar: HomeSnapshot.Bar) -> some View {
    switch bar.night {
    case .stopped(let count):
      Text("\(count)").tollType(.microNumber, TollColor.label2).padding(.bottom, 4)
    case .noBlock:
      Text(Copy.Home.noBlockNight).tollType(.microNumber, TollColor.label3).padding(.bottom, 4)
    case .ahead:
      EmptyView()
    }
  }

  @ViewBuilder private func shape(_ bar: HomeSnapshot.Bar, top: Int) -> some View {
    let shape = RoundedRectangle(cornerRadius: TollRadius.chartBar, style: .continuous)
    switch bar.night {
    case .stopped(let count):
      shape
        .fill(bar.isToday ? TollColor.accent : TollColor.bar)
        .frame(height: count == 0 ? 3 : max(4, 64 * CGFloat(count) / CGFloat(top)))
    case .noBlock:
      RoundedRectangle(cornerRadius: 1).fill(TollColor.separator).frame(height: 2)
    case .ahead:
      shape
        .strokeBorder(TollColor.bar, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        .frame(height: 64)
    }
  }

  private func spoken(_ bar: HomeSnapshot.Bar) -> String {
    switch bar.night {
    case .stopped(let count): "\(bar.day), \(count)"
    case .noBlock: "\(bar.day), \(Copy.Home.noBlockSpoken)"
    case .ahead: "\(bar.day), \(Copy.Home.aheadSpoken)"
    }
  }
}

/// The first nights: seven 40 pt slots, a blocked night in amber with a tick, the rest dashed.
struct FirstNights: View {
  let bars: [HomeSnapshot.Bar]

  var body: some View {
    HStack(spacing: 8) {
      ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
        VStack(spacing: 6) {
          slot(bar)
          Text(bar.day)
            .tollType(.micro, bar.night == .ahead ? TollColor.label2 : TollColor.label)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bar.day)
      }
    }
  }

  @ViewBuilder private func slot(_ bar: HomeSnapshot.Bar) -> some View {
    let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
    switch bar.night {
    case .stopped:
      shape.fill(TollColor.accentSoft)
        .overlay(shape.strokeBorder(TollColor.accent, lineWidth: 1))
        .overlay(Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold)))
        .foregroundStyle(TollColor.accent)
        .frame(height: 40)
    case .noBlock:
      shape.fill(TollColor.surfaceRaised).frame(height: 40)
    case .ahead:
      shape.strokeBorder(TollColor.bar, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        .frame(height: 40)
    }
  }
}

/// Home's blocks: 58 pt rows, the leading tile amber for the block that is on or next tonight.
struct BlockList: View {
  let rows: [HomeSnapshot.BlockRow]
  var open: ((BlockID) -> Void)?

  var body: some View {
    Card {
      ForEach(rows) { row in
        Button {
          open?(row.id)
        } label: {
          CardRow(row.name, detail: row.detail, size: .list) {
            IconTile(BlockSymbol.name(row.kind), accent: row.trailingIsAccent)
          } trailing: {
            Text(row.trailing)
              .tollType(.trailing, row.trailingIsAccent ? TollColor.accent : TollColor.label2)
          }
        }
        .buttonStyle(.plain)
        .disabled(open == nil)
      }
    }
  }
}

/// Outline symbols, as the canvas draws its icons.
enum BlockSymbol {
  static func name(_ kind: Block.Kind) -> String {
    switch kind {
    case .sleep: "moon"
    case .study: "book"
    case .work: "briefcase"
    case .gym: "figure.run"
    case .other: "square.grid.2x2"
    }
  }
}
