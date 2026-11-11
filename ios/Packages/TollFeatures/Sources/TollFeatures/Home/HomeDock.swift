import SwiftUI
import TollCore
import TollUI

/// Home's bottom dock (design §4.1): the Toll-opens caption, then the block bar, 8 pt above the tab
/// bar. Anchored to the bottom safe area instead of the end of the list, so it is in the same place
/// with no friends and with forty. Rows fade out under its top edge rather than colliding with the
/// text. Its own view, so a change to the blocks or the count redraws the dock and not all of Home.
struct HomeDock: View {
  let app: AppModel
  let model: HomeModel?
  /// The bar is the source the block cards zoom out of (design §2.5).
  let barSpace: Namespace.ID
  let onBar: () -> Void

  static let barID = "blockBar"
  private static let fade: CGFloat = 20

  var body: some View {
    VStack(spacing: 0) {
      Text(Copy.Home.tollOpens(app.tollOpensToday))
        .tollText(.caption)
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, Self.fade + 4)
        .padding(.bottom, TollSpacing.labelGap)
        // Touches on the caption and the fade belong to the rows scrolling beneath them.
        .allowsHitTesting(false)
      if let summary = BlockBarSummary(model?.blockStates ?? []) {
        ActiveBlockBar(summary: summary, action: onBar)
          .matchedTransitionSource(id: Self.barID, in: barSpace)
          .padding(.bottom, TollSpacing.labelGap)
      }
    }
    .tollGutter()
    .background {
      VStack(spacing: 0) {
        LinearGradient(
          colors: [TollColor.bg.opacity(0), TollColor.bg], startPoint: .top, endPoint: .bottom
        )
        .frame(height: Self.fade)
        TollColor.bg
      }
      .ignoresSafeArea(edges: .bottom)
      .allowsHitTesting(false)
    }
  }
}
