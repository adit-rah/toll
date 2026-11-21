import SwiftUI
import TollCore
import TollUI

/// The transition log (B-6), newest first. Kept until the founders remove it (spec §2).
struct TransitionLogView: View {
  let model: AppModel

  var body: some View {
    List {
      LabeledContent(Copy.Settings.version, value: AppLinks.version)
      // For the founders' replays and data science (#51, #87): the night records as a file.
      ShareLink(item: NightLog().url) {
        Text(Copy.Settings.shareNights)
      }
      if model.log.isEmpty {
        Text(Copy.Settings.logEmpty).tollType(.body, TollColor.label2)
      }
      ForEach(Array(model.log.enumerated()), id: \.offset) { _, line in
        Text(Copy.Settings.line(line)).tollType(.detail, TollColor.label)
      }
    }
    .scrollContentBackground(.hidden)
    .background(TollColor.bg)
    .navigationTitle(Copy.Settings.log)
  }
}
