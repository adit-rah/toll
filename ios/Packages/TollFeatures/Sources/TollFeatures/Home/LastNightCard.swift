import SwiftUI
import TollCore
import TollUI

/// Last night, to review (D65, #103): what the card is about, a sentence that says what the bar
/// shows, the night as a moon → sun bar filled where apps were locked with a break where they were
/// open, "You chose sleep over a locked app 3 times" when there were any, and the last seven nights
/// as dots under their title. Each morning it floats in Tonight's band with "OK"; the strip's start
/// opens the same content all day, without the card around it.
struct LastNightCard: View {
  let night: Morning
  /// In the band: "OK" puts it away for this morning. Nil in the strip's snippet.
  var putAway: (() -> Void)?

  var body: some View {
    if putAway != nil {
      content
        .padding(.vertical, TollSpacing.noteCardVertical)
        .padding(.horizontal, TollSpacing.cardPadding)
        .background(
          TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous)
        )
    } else {
      content
    }
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline) {
        StateLine(night.eyebrow, symbol: .sleep)
          .accessibilityElement(children: .combine)
          .accessibilityAddTraits(.isHeader)
        Spacer(minLength: 8)
        if let putAway {
          Button(Copy.Morning.ok, action: putAway)
            .tollType(.action, TollColor.label2)
            .frame(minWidth: TollSpacing.minTapTarget, minHeight: TollSpacing.minTapTarget)
            .contentShape(Rectangle())
            // A full-size target that doesn't make the row taller.
            .padding(.vertical, -14)
            .padding(.trailing, -8)
        }
      }
      VStack(alignment: .leading, spacing: 0) {
        Text(night.headline)
          .tollType(.rowTitle, TollColor.label)
          .fixedSize(horizontal: false, vertical: true)
        NightBar(morning: night).padding(.top, 10)
        if let open = night.openLine {
          Text(open)
            .tollType(.detail, TollColor.label2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
        }
      }
      .padding(.top, 8)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(night.spoken)
      if let putDown = night.putDown {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Image(symbol: .phoneDown).unredacted()
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(TollColor.label2)
            .accessibilityHidden(true)
          Text(putDown)
            .tollType(.body, TollColor.label)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .padding(.top, 12)
      }
      if let landmark = night.landmark {
        LandmarkLine(landmark: landmark).padding(.top, 14)
      }
      Text(night.weekTitle)
        .tollType(.eyebrow, TollColor.label2)
        .accessibilityAddTraits(.isHeader)
        .padding(.top, 16)
        .padding(.bottom, 8)
      NightDots(bars: night.week)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The night from its planned start to its planned end: solid where apps were locked, the track
/// showing through a break; an outline when nothing locked. The moon and the sun at its ends say
/// which way the night runs; the sentence over it holds the times.
private struct NightBar: View {
  let morning: Morning

  var body: some View {
    HStack(spacing: 8) {
      glyph(.sleep)
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
      // Sleep full height, the buffers around it lower (#144): three parts by shape.
      .mask { SleepShape(sleep: morning.sleep) }
      glyph(.sun)
    }
    .tollChartTypeLimit()
  }

  private func glyph(_ symbol: TollSymbol) -> some View {
    Image(symbol: symbol).unredacted()
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(TollColor.label2)
  }
}

/// The night bar's outline: full height over sleep, half height over the buffers either side.
private struct SleepShape: View {
  let sleep: Morning.Span

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      ZStack(alignment: .leading) {
        Rectangle().frame(height: proxy.size.height / 2)
        Rectangle()
          .frame(width: max(4, width * (sleep.end - sleep.start)))
          .offset(x: width * sleep.start)
      }
      .frame(maxHeight: .infinity)
    }
  }
}
