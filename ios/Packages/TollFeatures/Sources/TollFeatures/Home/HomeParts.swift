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
          IconTile(.sleep, size: .large)
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
      HourLabels(hours: timeline.hours)
    }
    .tollChartTypeLimit()
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

/// The strip's hours, evenly spaced ("6 pm  10 pm  2 am  6 am  10 am" on the boards' night), the ends
/// held to its edges, in the phone's format. The snapshot picks them to fit the block (#82).
private struct HourLabels: View {
  let hours: [String]

  var body: some View {
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
