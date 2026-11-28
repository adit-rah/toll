import SwiftUI
import TollCore
import TollUI

/// The one optional card under the pill (#102), laid out from the snapshot's `TonightCard`. Quiet:
/// `surface`, the offer's own symbol, one link that opens it and "Not now" that puts it away for good.
struct TonightCardView: View {
  let card: TonightCard
  /// The heads-up the card offers, for its time (#104).
  var headsUp: HeadsUp?
  /// A gap card's words (D76): Monday's, or the offer.
  var gap: GapCard?
  /// Minutes until bed, for Before bed's card (D80).
  var untilBed: Int?
  let open: () -> Void
  let dismiss: () -> Void

  var body: some View {
    let content = self.content
    BandCard(
      symbol: content.symbol, title: content.title, detail: content.detail,
      action: content.action, dismiss: content.dismiss, open: open, putAway: dismiss)
  }

  /// Each kind's words and symbol; a new kind adds its case here (#104). No action: the card only
  /// says something, and its one button puts it away.
  private var content:
    (symbol: TollSymbol, title: String, detail: String?, action: String?, dismiss: String)
  {
    switch card {
    case .home:
      (.home, Copy.Home.homeCard, Copy.Home.homeCardDetail, Copy.Home.setHome, Copy.Home.notNow)
    // A bell and a time, so it reads without the words (design §5).
    case .headsUp:
      (
        .headsUp, Copy.HeadsUp.card,
        Copy.HeadsUp.cardDetail(
          time: headsUp.map { Copy.time($0.at) },
          minutes: TollConfig.defaults.headsUp.leadMinutes),
        Copy.HeadsUp.turnOn, Copy.Home.notNow
      )
    // The gap's own glyph, before the moon (D76).
    case .gapWeek, .gapOffer:
      (
        .beforeBed, gap?.title ?? "", gap?.detail, gap?.action,
        gap?.dismiss ?? Copy.Home.notNow
      )
    // The capsule's glyph, so the card reads as the capsule's (D80).
    case .beforeBed:
      (
        .beforeBed, Copy.Helpers.card(minutes: untilBed ?? 0), Copy.Helpers.cardDetail,
        Copy.Helpers.showMe, Copy.Home.notNow
      )
    }
  }
}

/// A card in Tonight's band: its symbol, its words, one link that opens it and a quiet word that
/// puts it away. Tonight's offers and the one-time flows (#140) share it. An answer (the heads-up
/// on, #160) has an amber tile, since what it names is now on, and its title carries the tick, so
/// it reads apart from the offer it answers without the words.
struct BandCard: View {
  let symbol: TollSymbol
  let title: String
  let detail: String?
  let action: String?
  let dismiss: String
  /// The tile in amber, and a tick before the title: what the card names is on (#160).
  var done = false
  /// The action leaves for iOS Settings, so it carries that glyph instead of the chevron.
  var leaves = false
  let open: () -> Void
  let putAway: () -> Void
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    HStack(alignment: .top, spacing: TollSpacing.rowGap) {
      IconTile(symbol, accent: done)
      VStack(alignment: .leading, spacing: 0) {
        words
          .accessibilityElement(children: .combine)
        // Side by side; stacked at accessibility sizes so neither action truncates.
        let actions =
          typeSize.isAccessibilitySize
          ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
          : AnyLayout(HStackLayout(spacing: 20))
        actions {
          if let action {
            Button(action: open) {
              HStack(spacing: 4) {
                Text(action)
                Image(symbol: leaves ? .openSettings : .forward).unredacted()
                  .tollGlyph(12, weight: .bold)
                  .accessibilityHidden(true)
              }
            }
            .tollType(.action, TollColor.accent)
            .frame(minHeight: TollSpacing.minTapTarget)
          }
          Button(dismiss, action: putAway)
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
    .tollSurface()
  }

  @ViewBuilder private var words: some View {
    if done {
      VStack(alignment: .leading, spacing: 1) {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Image(symbol: .done).unredacted()
            .tollGlyph(13, weight: .bold)
            .foregroundStyle(TollColor.accent)
            .accessibilityHidden(true)
          Text(title).tollType(.rowTitle, TollColor.label)
        }
        if let detail { Text(detail).tollType(.detail, TollColor.label2) }
      }
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      RowText(title: title, detail: detail)
    }
  }
}
