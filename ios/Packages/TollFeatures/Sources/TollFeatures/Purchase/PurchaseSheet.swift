import SwiftUI
import TollCore
import TollData
import TollUI

/// The purchase (the design canvas): what the free week did, what buying keeps, the price once. Opens
/// only from the last-day pill, Home's Paused card and Settings (D33).
struct PurchaseSheet: View {
  let model: AppModel
  let home: HomeSnapshot
  @Environment(\.dismiss) private var dismiss
  @State private var working = false
  @State private var note: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: TollSpacing.groupGap) {
        VStack(alignment: .leading, spacing: 8) {
          Text(Copy.Purchase.eyebrow).font(TollFont.captionMedium).foregroundStyle(TollColor.label2)
          Text(Copy.Purchase.title)
            .font(TollFont.screenTitle)
            .foregroundStyle(TollColor.label)
            .accessibilityAddTraits(.isHeader)
        }
        StatTiles(home: home)
        Card {
          ForEach(Copy.Purchase.benefits, id: \.self) { benefit in
            Label(benefit, systemImage: "checkmark")
              .font(TollFont.body)
              .foregroundStyle(TollColor.label)
              .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
          }
        }
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(model.price).font(.system(.largeTitle, weight: .semibold)).monospacedDigit()
          Text(Copy.Purchase.once).font(TollFont.body).foregroundStyle(TollColor.label2)
        }
        .foregroundStyle(TollColor.label)
        .accessibilityElement(children: .combine)
        if let note { Footnote(note).transition(.opacity) }
        Footnote(Copy.Purchase.footnote)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .tollGutter()
      .padding(.top, TollSpacing.titleGap)
    }
    .background(TollColor.bg)
    .animation(Motion.stateChange, value: note)
    .tollBottomBar(background: TollColor.bg) {
      VStack(spacing: 0) {
        PrimaryButton(Copy.Purchase.keep) { Task { await buy() } }.disabled(working)
        HStack {
          QuietButton(Copy.Purchase.restore, tone: .secondary) { Task { await restore() } }
          Spacer()
          QuietButton(Copy.Purchase.notNow, tone: .secondary) { dismiss() }
        }
        .disabled(working)
      }
    }
  }

  private func buy() async {
    working = true
    defer { working = false }
    switch await model.buy() {
    case .purchased: dismiss()
    case .cancelled: note = nil
    case .pending: note = Copy.Trial.pending
    case .failed: note = Copy.Trial.failed
    }
  }

  private func restore() async {
    working = true
    defer { working = false }
    if await model.restore() { dismiss() } else { note = Copy.Trial.nothingToRestore }
  }
}

/// The week's numbers as tiles (the canvas's "This week" card and the purchase sheet).
struct StatTiles: View {
  let home: HomeSnapshot

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      tile(
        Copy.Home.nightsBlocked(
          home.nightsBlocked, of: max(home.nightsCounted, home.nightsBlocked)),
        Copy.Home.nightsBlockedLabel)
      tile("\(home.timesStopped)", Copy.Home.stoppedLabel)
    }
  }

  private func tile(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value).font(TollFont.title).monospacedDigit().foregroundStyle(TollColor.label)
      Text(label).font(TollFont.detail).foregroundStyle(TollColor.label2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}
