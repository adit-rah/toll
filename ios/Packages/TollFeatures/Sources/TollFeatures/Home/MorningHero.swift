import SwiftUI
import TollCore
import TollUI

/// Last night, from the end of the night until noon (D65, #103), in the hero's own form so the most
/// seen screen keeps one look through the day: the eyebrow, how long apps were locked set like the
/// evening's time, the hours from moon to sun, "You chose sleep 3 times" when there were any, and
/// the week's nights as the hero's row of dots. No card. When nothing blocked, the reason's glyph
/// takes the number's place, as Off's does, and the line under the hours says why.
struct MorningHero: View {
  let morning: Morning
  let nights: [HomeSnapshot.Bar]

  var body: some View {
    VStack(spacing: 6) {
      VStack(spacing: 6) {
        StateLine(morning.eyebrow, symbol: .sleep)
        if let locked = morning.locked {
          HeroLength(minutes: locked)
        } else {
          Image(symbol: outcomeSymbol).unredacted()
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(TollColor.label2)
            .frame(width: 64, height: 64)
            .padding(.vertical, 6)
            .accessibilityHidden(true)
        }
        hours
        if let line {
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let symbol = line.symbol {
              Image(symbol: symbol).unredacted()
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TollColor.label2)
                .accessibilityHidden(true)
            }
            Text(line.text).tollType(.heroLine, TollColor.label2)
          }
        }
      }
      .multilineTextAlignment(.center)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
      NightDots(bars: nights, compact: true).padding(.top, 10)
    }
    .frame(maxWidth: .infinity)
  }

  /// "☾ 10:15 pm – 7:00 am ☀": where the night began and ended reads without the words. VoiceOver
  /// hears the hours with any open stretch in them.
  private var hours: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      glyph(.sleep)
      Text(Copy.Morning.span(from: morning.from, to: morning.to))
        .tollType(.heroLine, TollColor.label)
      glyph(.sun)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(morning.spoken)
  }

  private func glyph(_ symbol: TollSymbol) -> some View {
    Image(symbol: symbol).unredacted()
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(TollColor.label2)
  }

  /// The glyph in the number's place when nothing blocked.
  private var outcomeSymbol: TollSymbol {
    morning.outcome == .noScreenTime ? .screenTime : .away
  }

  /// The taps when there were any; or why nothing blocked, whose glyph is already the big one.
  private var line: (symbol: TollSymbol?, text: String)? {
    switch morning.outcome {
    case .ran: morning.putDown.map { (TollSymbol.phoneDown, $0) }
    case .away: (nil, Copy.Morning.away)
    case .noScreenTime: (nil, Copy.Morning.noScreenTime)
    }
  }
}
