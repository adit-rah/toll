import SwiftUI
import TollCore
import TollData
import TollUI

/// "Turn Dusk back on · $9.99 once, for good": the one card after the trial (D33), with Off's glyph,
/// and the one thing to tap there (the audit).
struct OffCard: View {
  let price: String
  let open: () -> Void

  var body: some View {
    Button(action: open) {
      Card {
        CardRow(
          Copy.Home.turnBackOn, detail: Copy.Home.onceEveryNight(price),
          size: RowSize(minHeight: 68, tile: .large)
        ) {
          IconTile(.off, size: .large)
        } trailing: {
          Chevron()
        }
      }
    }
    .buttonStyle(.plain)
  }
}

/// What Settings' location says, as one fact (D37).
func locationFact(_ state: LocationAccess.State) -> String {
  switch state {
  case .approximate: Copy.Setup.approximateFact
  case .denied, .notDetermined: Copy.Setup.deniedFact
  case .whileUsing, .always: Copy.Setup.whileUsingFact
  }
}
