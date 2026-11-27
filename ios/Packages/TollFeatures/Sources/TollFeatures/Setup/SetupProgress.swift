import SwiftUI
import TollCore
import TollUI

extension View {
  /// Setup's progress segments, fixed over a navigation stack's bar (design §2.5's "Setup step
  /// push"): one instance for the whole flow, so it stays still while pages slide under it, and the
  /// new step fills once the push has landed. `step` is 1-based; nil hides it (Welcome, Ready).
  /// `inset` keeps it clear of the bar's leading button, mirrored on the right so it's centred.
  func setupProgress(step: Int?, of steps: Int, inset: CGFloat = 28) -> some View {
    overlay(alignment: .top) {
      SetupProgress(step: step, steps: steps, inset: inset)
    }
  }
}

private struct SetupProgress: View {
  let step: Int?
  let steps: Int
  let inset: CGFloat
  /// The step the bar shows: it follows `step` once the push has landed.
  @State private var shown: Int?
  @State private var width: CGFloat = 390
  @State private var started = false

  /// The system push is about this long; the fill starts after it (design §2.5).
  static let pushLands: Duration = .milliseconds(350)

  var body: some View {
    ZStack {
      if let shown {
        ProgressSegments(
          count: steps, current: shown - 1, accessibilityLabel: Copy.Setup.step(shown, of: steps)
        )
        .frame(width: barWidth)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: TollSpacing.barHeight)
    .onGeometryChange(for: CGFloat.self) {
      $0.size.width
    } action: {
      width = $0
    }
    .allowsHitTesting(false)
    .task(id: step) {
      // Leaving the counted steps hides it at once; a step reached by a push waits for the page
      // to land. The flow's first page (a sheet's root, a deep link) is already there.
      defer { started = true }
      guard let step else {
        shown = nil
        return
      }
      if started { try? await Task.sleep(for: Self.pushLands) }
      guard !Task.isCancelled else { return }
      shown = step
    }
  }

  /// The board's bar: the leading button and 14 pt either side of the segments, mirrored on the
  /// right so the segments sit centred.
  private var barWidth: CGFloat {
    let gutter = TollSpacing.horizontalGutter(forWidth: width)
    return max(120, width - 2 * (gutter + inset + 14))
  }
}
