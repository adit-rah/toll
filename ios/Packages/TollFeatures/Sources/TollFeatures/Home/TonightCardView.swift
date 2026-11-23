import SwiftUI
import TollCore
import TollUI

/// The one optional card under the pill (#102), laid out from the snapshot's `TonightCard`. Quiet:
/// `surface`, the offer's own symbol, one link that opens it and "Not now" that puts it away for good.
struct TonightCardView: View {
  let card: TonightCard
  /// The heads-up the card offers, for its time (#104).
  var headsUp: HeadsUp?
  let open: () -> Void
  let dismiss: () -> Void
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    HStack(alignment: .top, spacing: TollSpacing.rowGap) {
      IconTile(content.symbol, accent: false)
      VStack(alignment: .leading, spacing: 0) {
        RowText(title: content.title, detail: content.detail)
          .accessibilityElement(children: .combine)
        // Side by side; stacked at accessibility sizes so neither action truncates.
        let actions =
          typeSize.isAccessibilitySize
          ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
          : AnyLayout(HStackLayout(spacing: 20))
        actions {
          Button(action: open) {
            HStack(spacing: 4) {
              Text(content.action)
              Image(symbol: .forward).unredacted()
                .font(.system(size: 12, weight: .bold))
                .accessibilityHidden(true)
            }
          }
          .tollType(.action, TollColor.accent)
          .frame(minHeight: TollSpacing.minTapTarget)
          Button(Copy.Home.notNow, action: dismiss)
            .tollType(.action, TollColor.label2)
            .frame(minHeight: TollSpacing.minTapTarget)
        }
        .padding(.top, 2)
      }
    }
    .padding(.top, TollSpacing.noteCardVertical)
    .padding(.bottom, 2)
    .padding(.horizontal, TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }

  /// Each kind's words and symbol; a new kind adds its case here (#104).
  private var content: (symbol: TollSymbol, title: String, detail: String, action: String) {
    switch card {
    case .home: (.home, Copy.Home.homeCard, Copy.Home.homeCardDetail, Copy.Home.setHome)
    // A bell and a time, so it reads without the words (design §5).
    case .headsUp:
      (
        .headsUp, Copy.HeadsUp.card,
        Copy.HeadsUp.cardDetail(
          time: headsUp.map { Copy.time($0.at) },
          minutes: TollConfig.defaults.headsUp.leadMinutes),
        Copy.HeadsUp.turnOn
      )
    }
  }
}
