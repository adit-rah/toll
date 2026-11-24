import SwiftUI
import TollCore
import TollUI

/// Last night, in the hero's place from the end of the night until noon (D65, #103): the night as a
/// moon → sun bar filled where the block ran, a break where it was open; "You put it down 3 times"
/// when there were any; and the last seven nights as dots. One number, and it reads without words.
struct MorningCard: View {
  let morning: Morning
  let nights: [HomeSnapshot.Bar]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StateLine(Copy.Morning.lastNight, symbol: .sleep)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
      NightBar(morning: morning).padding(.top, 16)
      if let line {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Image(symbol: line.symbol).unredacted()
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(TollColor.label2)
            .accessibilityHidden(true)
          Text(line.text)
            .tollType(.rowTitle, TollColor.label)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .padding(.top, 18)
      }
      if let landmark = morning.landmark {
        LandmarkLine(landmark: landmark).padding(.top, 18)
      }
      Hairline().padding(.vertical, 16)
      NightDots(bars: nights)
    }
    .padding(.vertical, TollSpacing.statsCardVertical)
    .padding(.horizontal, TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }

  /// The card's one line: the taps when there were any, or why nothing blocked.
  private var line: (symbol: TollSymbol, text: String)? {
    switch morning.outcome {
    case .ran:
      guard let putDown = morning.putDown else { return nil }
      return (TollSymbol.phoneDown, putDown)
    case .away: return (TollSymbol.away, Copy.Morning.away)
    case .noScreenTime: return (TollSymbol.screenTime, Copy.Morning.noScreenTime)
    }
  }
}

/// The night from its planned start to its planned end: solid where the block ran, the track
/// showing through a gap; an outline when nothing blocked. The moon and the sun hold the times.
private struct NightBar: View {
  let morning: Morning

  var body: some View {
    VStack(spacing: 10) {
      GeometryReader { proxy in
        let width = proxy.size.width
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        ZStack(alignment: .leading) {
          if morning.outcome == .ran {
            shape.fill(TollColor.surfaceRaised)
            ForEach(Array(morning.ran.enumerated()), id: \.offset) { _, span in
              shape.fill(TollColor.accent)
                .frame(width: max(4, width * (span.end - span.start)))
                .offset(x: width * span.start)
            }
          } else {
            shape.strokeBorder(TollColor.label3, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
          }
        }
      }
      .frame(height: 10)
      HStack {
        end(.sleep, morning.from, leading: true)
        Spacer(minLength: 8)
        end(.sun, morning.to, leading: false)
      }
      .tollType(.detail, TollColor.label2)
    }
    .tollChartTypeLimit()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(morning.spoken)
  }

  private func end(_ symbol: TollSymbol, _ time: String, leading: Bool) -> some View {
    HStack(spacing: 5) {
      if leading { glyph(symbol) }
      Text(time)
      if !leading { glyph(symbol) }
    }
  }

  private func glyph(_ symbol: TollSymbol) -> some View {
    Image(symbol: symbol).unredacted().font(.system(size: 12, weight: .semibold))
  }
}
