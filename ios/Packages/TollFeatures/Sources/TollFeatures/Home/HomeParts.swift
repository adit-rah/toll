import SwiftUI
import TollCore
import TollData
import TollUI

/// "Turn it back on · $9.99 once · every night after": the one card after the trial (D33).
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
          IconTile(.sleep, size: .large)
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
