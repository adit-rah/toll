import SwiftUI
import TollCore
import TollUI

/// The night as a picture (D68, #76): moon, start – end, sun, over a strip of the night alone. Turning
/// the wake wheel slides the night along the strip, so the change shows without words. It changes
/// with no motion: design §2.5 has no row for it. Tonight's strip is the whole day (D75); setup and
/// Blocks' night card stay on the night, which is all they're about.
struct NightPictureView: View {
  let picture: NightPicture

  var body: some View {
    VStack(spacing: 4) {
      HStack(spacing: 10) {
        glyph(.sleep)
        Text(Copy.Setup.nightSpan(start: picture.start, end: picture.end))
          .tollType(.stat, TollColor.label)
          .monospacedDigit()
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
        glyph(.sun)
      }
      .frame(maxWidth: .infinity)
      NightStrip(strip: picture.timeline)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(picture.timeline.label)
  }

  private func glyph(_ symbol: TollSymbol) -> some View {
    Image(symbol: symbol).unredacted()
      .font(.system(size: 18, weight: .medium))
      .foregroundStyle(TollColor.accent)
  }
}

/// The night on the boards' 6 pm → 10 am strip (or one fitted to it, #82): an 8 pt track, the night
/// solid while on, outlined before, dashed when nothing will block.
struct NightStrip: View {
  let strip: NightPicture.Strip

  var body: some View {
    VStack(spacing: 10) {
      GeometryReader { proxy in
        let width = proxy.size.width
        ZStack(alignment: .topLeading) {
          RoundedRectangle(cornerRadius: 4).fill(TollColor.surfaceRaised).frame(height: 8)
          night
            .frame(width: max(8, width * (strip.end - strip.start)), height: 8)
            .offset(x: width * strip.start)
        }
      }
      .frame(height: 8)
      .padding(.top, 26)
      EvenHourLabels(hours: strip.hours)
    }
    .tollChartTypeLimit()
  }

  @ViewBuilder private var night: some View {
    let shape = RoundedRectangle(cornerRadius: 4)
    switch strip.phase {
    case .on: shape.fill(TollColor.accent)
    case .upcoming: shape.fill(TollColor.accentSoft).overlay(shape.stroke(TollColor.accent))
    case .off:
      shape.stroke(TollColor.label3, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
    }
  }
}

/// The strip's hours, evenly spaced ("6 pm  10 pm  2 am  6 am  10 am" on the boards' night), the ends
/// held to its edges, in the phone's format.
private struct EvenHourLabels: View {
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
