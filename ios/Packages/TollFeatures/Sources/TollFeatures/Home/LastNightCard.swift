import SwiftUI
import TollCore
import TollUI

/// Last night, to review (D65, #103): what the card is about, a sentence that says what the bar
/// shows, the night as a moon → sun bar filled where apps were locked with a break where they were
/// open, "You chose sleep over a locked app 3 times" when there were any, and the last seven nights
/// as dots under their title. The strip's start opens it all day; each morning Tonight's band holds
/// it folded to one row (`LastNightBand`), with the same details when it opens.
struct LastNightCard: View {
  let night: Morning

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      StateLine(night.eyebrow, symbol: .sleep)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
      LastNightDetails(night: night).padding(.top, 8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Everything under "Last night": the sentence, the bar and its breaks, the taps, a landmark, and
/// the seven nights.
struct LastNightDetails: View {
  let night: Morning
  @Environment(\.askHealth) private var askHealth

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 0) {
        // Health's sleep leads when there is some (#88); the lock is then the line under the bar.
        Text(night.asleep?.line ?? night.headline)
          .tollType(.rowTitle, TollColor.label)
          .fixedSize(horizontal: false, vertical: true)
        NightBar(morning: night).padding(.top, 10)
        if night.asleep != nil {
          Text(night.headline)
            .tollType(.detail, TollColor.label2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
        }
        if let open = night.openLine {
          Text(open)
            .tollType(.detail, TollColor.label2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        [night.asleep?.spoken, night.spoken].compactMap { $0 }.joined(separator: ". "))
      // Once, the morning after the first night, for someone who skipped Health (#86).
      if night.asksHealth, let askHealth {
        HealthLink(title: Copy.Morning.seeHowYouSlept, action: askHealth).padding(.top, 6)
      }
      if night.healthEmpty {
        Footnote(Copy.Morning.healthEmpty, symbol: .health).padding(.top, 10)
      }
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
/// which way the night runs; the sentence over it holds the times. A break that was a pause has the
/// pause's glyph over it (#124), so it doesn't read as a glitch; a time away has none.
private struct NightBar: View {
  let morning: Morning
  private static let mark: CGFloat = 12

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
        .overlay(alignment: .topLeading) {
          ForEach(Array(pauses.enumerated()), id: \.offset) { _, gap in
            Image(symbol: .unlock).unredacted()
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(TollColor.label2)
              .frame(width: Self.mark, height: Self.mark)
              .offset(
                x: width * (gap.start + gap.end) / 2 - Self.mark / 2, y: -(Self.mark + 2))
          }
          .accessibilityHidden(true)
        }
      }
      .frame(height: 10)
      // The buffers around sleep striped (#144): three parts by texture, not colour.
      .overlay { BufferStripes(sleep: morning.sleep) }
      // Health's sleep as a thin line under the lock, at its own place in the night (#88).
      .overlay(alignment: .bottomLeading) {
        if let asleep = morning.asleep {
          GeometryReader { proxy in
            Capsule()
              .fill(TollColor.label)
              .frame(
                width: max(4, proxy.size.width * (asleep.span.end - asleep.span.start)), height: 3
              )
              .offset(x: proxy.size.width * asleep.span.start, y: 14)
          }
          .accessibilityHidden(true)
        }
      }
      .padding(.bottom, morning.asleep == nil ? 0 : 7)
      glyph(.sun)
    }
    // Room over the bar for the pause's mark, only when there is one.
    .padding(.top, pauses.isEmpty ? 0 : Self.mark)
    .tollChartTypeLimit()
  }

  private var pauses: [Morning.Span] { morning.gaps.filter(\.paused) }

  private func glyph(_ symbol: TollSymbol) -> some View {
    Image(symbol: symbol).unredacted()
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(TollColor.label2)
  }
}

/// Stripes over the bar where the lock ran around sleep, before it and after waking, with a notch
/// at each edge of sleep.
private struct BufferStripes: View {
  let sleep: Morning.Span

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      ZStack(alignment: .leading) {
        if sleep.start > 0 {
          Hatch().stroke(TollColor.surface, lineWidth: 1.5)
            .frame(width: width * sleep.start)
          Rectangle().fill(TollColor.surface).frame(width: 2).offset(x: width * sleep.start - 1)
        }
        if sleep.end < 1 {
          Hatch().stroke(TollColor.surface, lineWidth: 1.5)
            .frame(width: width * (1 - sleep.end))
            .offset(x: width * sleep.end)
          Rectangle().fill(TollColor.surface).frame(width: 2).offset(x: width * sleep.end - 1)
        }
      }
      .clipped()
    }
    .accessibilityHidden(true)
  }
}
