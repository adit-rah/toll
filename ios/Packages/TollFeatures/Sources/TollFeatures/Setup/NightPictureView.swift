import SwiftUI
import TollCore
import TollUI

/// The night as a picture (D68, #76, #144): moon, asleep – wake, sun, over a strip of the night
/// alone; with buffers, the lock's ends under it, a lock where apps lock and an open lock where they
/// open. Changing a time slides the night along the strip, so the change shows without words. It
/// changes with no motion: design §2.5 has no row for it. Tonight's strip is the whole day (D75);
/// setup and Blocks' night card stay on the night, which is all they're about.
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
      if let lock = picture.lockTime, let open = picture.openTime {
        HStack(spacing: 6) {
          small(.blocked)
          Text(Copy.Fit.lockAt(lock))
          Spacer(minLength: 8)
          Text(Copy.Fit.openAt(open))
          small(.open)
        }
        .tollType(.detail, TollColor.label2)
        .monospacedDigit()
        .padding(.top, 4)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(picture.timeline.label)
  }

  private func small(_ symbol: TollSymbol) -> some View {
    Image(symbol: symbol).unredacted()
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(TollColor.label2)
  }

  private func glyph(_ symbol: TollSymbol) -> some View {
    Image(symbol: symbol).unredacted()
      .font(.system(size: 18, weight: .medium))
      .foregroundStyle(TollColor.accent)
  }
}

/// The night on the boards' 6 pm → 10 am strip (or one fitted to it, #82): an 8 pt track, the night
/// solid while on, outlined before, dashed when nothing will block. The buffers around sleep (D76,
/// #144) are thinner steps either side of it, each split from it by a notch, so the three parts
/// differ by height and place, never colour alone.
struct NightStrip: View {
  let strip: NightPicture.Strip

  var body: some View {
    VStack(spacing: 10) {
      GeometryReader { proxy in
        let width = proxy.size.width
        ZStack(alignment: .topLeading) {
          RoundedRectangle(cornerRadius: 4).fill(TollColor.surfaceRaised).frame(height: 8)
          if let lock = strip.lock, lock < strip.start {
            // 15 minutes is a few points: drawn at least 8 wide, ending 2 pt before the night.
            let step = max(8, width * (strip.start - lock) - 2)
            gap
              .frame(width: step, height: 4)
              .offset(x: width * strip.start - 2 - step, y: 2)
          }
          if let open = strip.open, open > strip.end {
            let step = max(8, width * (open - strip.end) - 2)
            gap
              .frame(width: step, height: 4)
              .offset(x: width * strip.end + 2, y: 2)
          }
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

  private var gap: some View {
    RoundedRectangle(cornerRadius: 2).fill(TollColor.accent)
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
