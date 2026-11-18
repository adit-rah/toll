import SwiftUI
import TollCore
import TollUI

/// The transition log (B-6), newest first. Kept until the founders remove it (spec §2).
struct TransitionLogView: View {
  let model: AppModel

  var body: some View {
    List {
      if model.log.isEmpty {
        Text(Copy.Settings.logEmpty).tollText(.subhead)
      }
      ForEach(Array(model.log.enumerated()), id: \.offset) { _, line in
        Text(Copy.Settings.line(line))
          .font(TollFont.caption)
          .monospacedDigit()
      }
    }
    .navigationTitle(Copy.Settings.log)
  }
}
