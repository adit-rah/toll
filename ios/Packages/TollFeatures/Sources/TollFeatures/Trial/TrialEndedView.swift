import SwiftUI
import TollCore
import TollData
import TollUI

/// Replaces Status once the trial is over and nothing is bought (spec §7, P-3): what the week was,
/// then the price. No other screen asks for money (P-5).
struct TrialEndedView: View {
  let summary: TrialSummary
  let unlocksUsed: Int
  let price: String
  let buy: () async -> Purchase.Outcome
  let restore: () async -> Bool
  @State private var working = false
  @State private var note: String?

  var body: some View {
    // A bar like Status's, though empty, so the title sits where Status's does.
    NavigationStack { page }
      .tint(TollColor.accent)
  }

  private var page: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: TollSpacing.groupGap) {
        ScreenTitle(Copy.Trial.endedTitle)
        VStack(alignment: .leading, spacing: TollSpacing.labelGap) {
          fact(Copy.Trial.nightsBlocked(summary.nightsBlocked))
          fact(Copy.Trial.blockScreens(summary.blockScreens))
          fact(Copy.Trial.unlocksUsed(unlocksUsed))
        }
        Text(Copy.Trial.without).tollText(.subhead)
        if let note {
          Text(note).tollText(.subhead).transition(.opacity)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .tollGutter()
    }
    .background(TollColor.bg)
    .animation(Motion.stateChange, value: note)
    .tollBottomBar(background: TollColor.bg) {
      VStack(spacing: TollSpacing.labelGap) {
        PrimaryButton(Copy.Trial.keep(price: price)) { Task { await purchase() } }
          .disabled(working)
        QuietButton(Copy.Trial.restore) { Task { await restorePurchase() } }
          .disabled(working)
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .navigationBar)
  }

  private func fact(_ text: String) -> some View {
    Text(text)
      .tollText(.body)
      .monospacedDigit()
      .fixedSize(horizontal: false, vertical: true)
  }

  private func purchase() async {
    working = true
    defer { working = false }
    switch await buy() {
    case .purchased, .cancelled: note = nil
    case .pending: note = Copy.Trial.pending
    case .failed: note = Copy.Trial.failed
    }
  }

  private func restorePurchase() async {
    working = true
    defer { working = false }
    note = await restore() ? nil : Copy.Trial.nothingToRestore
  }
}
