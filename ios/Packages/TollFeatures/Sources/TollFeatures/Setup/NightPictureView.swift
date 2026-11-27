import SwiftUI
import TollCore
import TollUI

/// The night as a picture (D68, #76, #144): moon, asleep – wake, sun, over a strip of the night
/// alone; with buffers, the lock's two ends marked on it, a lock where apps lock and an open lock
/// where they open. Changing a time slides the night along the strip, so the change shows without words. It
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
      NightStrip(
        strip: picture.timeline, lockTime: picture.lockTime, openTime: picture.openTime)
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

/// The night on the boards' 6 pm → 10 am strip (or one fitted to it, #82), at true scale. Sleep is
/// the solid bar with its moon; the buffers around it (D76, #144) are the same height, striped, each
/// split from sleep by a notch, so before · sleep · after read apart by texture and place, never
/// colour alone. The lock's two ends are marked over the bar with their times and lock glyphs.
/// Dashed when nothing will block.
struct NightStrip: View {
  let strip: NightPicture.Strip
  var lockTime: String?
  var openTime: String?

  static let height: CGFloat = 14
  static let notch: CGFloat = 2

  var body: some View {
    VStack(spacing: 8) {
      GeometryReader { proxy in
        let width = proxy.size.width
        let x = { (fraction: Double) in width * fraction }
        ZStack(alignment: .topLeading) {
          RoundedRectangle(cornerRadius: 5).fill(TollColor.surfaceRaised)
            .frame(height: Self.height)
          if let lock = strip.lock, lock < strip.start {
            buffer
              .frame(width: max(3, x(strip.start - lock) - Self.notch), height: Self.height)
              .offset(x: x(lock))
          }
          if let open = strip.open, open > strip.end {
            buffer
              .frame(width: max(3, x(open - strip.end) - Self.notch), height: Self.height)
              .offset(x: x(strip.end) + Self.notch)
          }
          night(width: max(8, x(strip.end - strip.start)))
            .frame(width: max(8, x(strip.end - strip.start)), height: Self.height)
            .offset(x: x(strip.start))
          if let lockTime {
            marker(lockTime, symbol: .blocked, at: x(strip.lock ?? strip.start), width: width)
          }
          if let openTime {
            marker(openTime, symbol: .open, at: x(strip.open ?? strip.end), width: width)
          }
        }
      }
      .frame(height: Self.height)
      .padding(.top, 26)
      EvenHourLabels(hours: strip.hours)
    }
    .tollChartTypeLimit()
  }

  /// A buffer: the night's colour, striped.
  @ViewBuilder private var buffer: some View {
    switch strip.phase {
    case .off:
      RoundedRectangle(cornerRadius: 3)
        .stroke(TollColor.label3, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
    case .on, .upcoming:
      HatchedBar(fill: TollColor.accent, stripes: TollColor.surface, radius: 3)
    }
  }

  @ViewBuilder private func night(width: CGFloat) -> some View {
    let shape = RoundedRectangle(cornerRadius: 5)
    switch strip.phase {
    case .on, .upcoming:
      shape.fill(TollColor.accent)
        .overlay {
          if width >= 22 {
            Image(symbol: .sleep).unredacted()
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(TollColor.onAccent)
          }
        }
    case .off:
      shape.stroke(TollColor.label3, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
    }
  }

  /// A tick at one of the lock's ends, its time and glyph over it, kept inside the strip.
  private func marker(_ time: String, symbol: TollSymbol, at x: CGFloat, width: CGFloat)
    -> some View
  {
    ZStack(alignment: .topLeading) {
      Rectangle().fill(TollColor.label2)
        .frame(width: 1, height: Self.height + 8)
        .offset(x: x - 0.5, y: -6)
      HStack(spacing: 3) {
        Image(symbol: symbol).unredacted().font(.system(size: 9, weight: .semibold))
        Text(time).monospacedDigit()
      }
      .tollType(.micro, TollColor.label2)
      .fixedSize()
      .position(x: min(max(x, 34), width - 34), y: -14)
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
