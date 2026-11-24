import SwiftUI
import TollCore
import TollData
import TollUI

/// The purchase (the canvas's Purchase sheet and its three outcomes): what the free week did, what
/// buying keeps, the price once. Opens only from the last-day pill, Home's Paused card and Settings
/// (D33). Closing Apple's payment sheet changes nothing here.
struct PurchaseSheet: View {
  let model: AppModel
  let home: HomeSnapshot
  @Environment(\.dismiss) private var dismiss
  @State private var working = false
  @State private var outcome: Outcome?

  init(model: AppModel, home: HomeSnapshot, outcome: Outcome? = nil) {
    self.model = model
    self.home = home
    _outcome = State(initialValue: outcome)
  }

  enum Outcome {
    /// Bought or restored: something appears, instead of the sheet just closing (#77).
    case purchased
    case pending, failed, nothingToRestore
  }

  var body: some View {
    Group {
      switch outcome {
      case nil: offer
      case .purchased:
        OutcomeSheet(
          symbol: .purchased, tint: TollColor.accent, title: Copy.Purchase.doneTitle,
          nights: model.config.trial.nights
        ) {
          PrimaryButton(Copy.Purchase.done) { dismiss() }
        }
      case .pending:
        OutcomeSheet(
          symbol: .askToBuy, tint: TollColor.accent, title: Copy.Purchase.pendingTitle,
          line: model.state.trial.entitled
            ? Copy.Purchase.pendingTrialBody : Copy.Purchase.pendingBody
        ) {
          PrimaryButton(Copy.Purchase.ok) { dismiss() }
        }
      case .failed:
        OutcomeSheet(
          symbol: .failed, tint: TollColor.warn, title: Copy.Purchase.failedTitle,
          line: Copy.Purchase.failedBody, overhang: 16
        ) {
          PrimaryButton(Copy.Purchase.tryAgain) { Task { await buy() } }.disabled(working)
          QuietButton(Copy.Purchase.notNow) { dismiss() }.frame(maxWidth: .infinity)
        }
      case .nothingToRestore:
        OutcomeSheet(
          symbol: .notFound, tint: TollColor.label2, title: Copy.Purchase.restoreNoneTitle,
          line: Copy.Purchase.restoreNoneBody
        ) {
          PrimaryButton(Copy.Purchase.ok) { outcome = nil }
        }
      }
    }
    .animation(Motion.movement, value: outcome)
  }

  private var offer: some View {
    SheetPage(height: 674, overhang: 14) {
      Text(Copy.Purchase.eyebrow).tollType(.eyebrow, TollColor.label2)
      // How much of the free nights is gone, as the pill draws it and says it (#77, the audit).
      if let free = home.freeWeek {
        FreeNights(
          used: free.bars.filter { $0.night != .ahead }.count, total: free.bars.count,
          tonight: home.pill.map { $0.night - 1 }, spoken: home.pill?.text ?? Copy.Purchase.eyebrow
        )
        .padding(.top, 8)
      }
      Text(Copy.Purchase.title)
        .tollType(TollType(size: 34, lineHeight: 40, weight: .semibold, style: .largeTitle))
        .foregroundStyle(TollColor.label)
        .accessibilityAddTraits(.isHeader)
        .padding(.top, 8)
      // The free nights only, frozen once they've ended (#48).
      let free = home.freeWeek
      AdaptiveStack(spacing: 12) {
        // Counts, never "5 of 7": a shortfall isn't shown (D65).
        let nights = free?.nightsBlocked ?? 0
        let putDown = free?.timesStopped ?? 0
        let used = free?.unlocksUsed ?? 0
        Stat(value: "\(nights)", label: Copy.Home.nightsLabel(nights), symbol: .sleep)
        Stat(value: "\(putDown)", label: Copy.Home.putDownLabel(putDown), symbol: .phoneDown)
        Stat(value: "\(used)", label: Copy.Purchase.usedLabel(used), symbol: .unlock)
      }
      .padding(.vertical, TollSpacing.statsCardVertical)
      .padding(.horizontal, TollSpacing.cardPadding)
      .background(
        TollColor.surfaceRaised,
        in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous)
      )
      .padding(.top, 22)
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Copy.Purchase.benefits, id: \.self) { benefit in
          HStack(spacing: 12) {
            Image(symbol: .done).unredacted()
              .font(.system(size: 15, weight: .bold))
              .foregroundStyle(TollColor.accent)
              .frame(width: 18)
              .accessibilityHidden(true)
            Text(benefit)
              .tollType(TollType(size: 16, lineHeight: 21, weight: .regular, style: .callout))
              .foregroundStyle(TollColor.label)
          }
          .frame(minHeight: 32)
        }
      }
      .padding(.top, 22)
    } actions: {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(model.price)
          .tollType(
            TollType(size: 34, lineHeight: 40, weight: .semibold, style: .largeTitle, tabular: true)
          )
          .foregroundStyle(TollColor.label)
        Text(Copy.Purchase.once).tollType(.body, TollColor.label2)
      }
      .accessibilityElement(children: .combine)
      .padding(.bottom, 14)
      PrimaryButton(Copy.Purchase.keep) { Task { await buy() } }.disabled(working)
      QuietButton(Copy.Purchase.restore, type: .smallQuiet) { Task { await restore() } }
        .frame(maxWidth: .infinity)
        .disabled(working)
      Text(Copy.Purchase.footnote)
        .tollType(TollType(size: 12, lineHeight: 17, weight: .regular, style: .caption))
        .foregroundStyle(TollColor.label2)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
  }

  private func buy() async {
    working = true
    defer { working = false }
    switch await model.buy() {
    case .purchased: outcome = .purchased
    case .cancelled: break
    case .pending: outcome = .pending
    case .failed: outcome = .failed
    }
  }

  private func restore() async {
    working = true
    defer { working = false }
    outcome = await model.restore() ? .purchased : .nothingToRestore
  }
}

/// Purchase · nothing to restore, from Settings' "Restore purchase".
struct RestoreNoneSheet: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    OutcomeSheet(
      symbol: .notFound, tint: TollColor.label2, title: Copy.Purchase.restoreNoneTitle,
      line: Copy.Purchase.restoreNoneBody
    ) {
      PrimaryButton(Copy.Purchase.ok) { dismiss() }
    }
  }
}

/// Purchase · waiting for approval, failed, nothing to restore: a 48 pt tile, a title, a sentence.
private struct OutcomeSheet<Actions: View>: View {
  let symbol: TollSymbol
  let tint: Color
  let title: String
  var line: String?
  /// After buying: the free nights' segments, all filled.
  var nights: Int?
  var overhang: CGFloat = 0
  @ViewBuilder let actions: Actions

  var body: some View {
    SheetPage(height: 374, overhang: overhang) {
      Image(symbol: symbol).unredacted()
        .font(.system(size: TileSize.sheet.symbol, weight: .medium))
        .foregroundStyle(tint)
        .frame(width: TileSize.sheet.side, height: TileSize.sheet.side)
        .background(
          TollColor.surfaceRaised,
          in: RoundedRectangle(cornerRadius: TileSize.sheet.radius, style: .continuous)
        )
        .accessibilityHidden(true)
      SheetTitle(title).padding(.top, 18)
      if let line { SheetBody(line) }
      if let nights {
        FreeNights(used: nights, total: nights, spoken: title).padding(.top, 14)
      }
    } actions: {
      actions
    }
  }
}
