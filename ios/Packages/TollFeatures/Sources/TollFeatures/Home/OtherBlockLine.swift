import SwiftUI
import TollCore
import TollUI

/// Tonight's one line about another block, only while one is on (D68, #89): a lock and the block's
/// kind before "Study on until 5:00 pm", in grey under the night's state. While the night isn't on,
/// the quiet "Pause" capsule rides at its end, since a pause lifts every block (D67).
struct OtherBlockLine: View {
  let line: HomeSnapshot.OtherBlock
  let openDoor: () -> Void
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))
    layout {
      HStack(spacing: 6) {
        Image(symbol: .blocked).unredacted()
          .foregroundStyle(TollColor.accent)
          .accessibilityHidden(true)
        Image(symbol: .block(line.kind)).unredacted()
          .accessibilityHidden(true)
        Text(line.text).tollType(.heroLine, TollColor.label2)
      }
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(TollColor.label2)
      .accessibilityElement(children: .combine)
      if line.offersPause {
        Button(action: openDoor) {
          HStack(spacing: 6) {
            Image(symbol: .unlock).unredacted()
              .font(.system(size: 13, weight: .semibold))
              .accessibilityHidden(true)
            Text(Copy.Home.pause)
          }
          .tollType(.smallQuiet, TollColor.label2)
          .padding(.horizontal, 12)
          .frame(minHeight: 32)
          .background(TollColor.surfaceRaised, in: Capsule())
          .frame(minHeight: TollSpacing.minTapTarget)
          .contentShape(Rectangle())
        }
        .buttonStyle(.tollPressable)
        .accessibilityLabel(Copy.Home.pauseSpoken)
      }
    }
    .frame(maxWidth: .infinity)
  }
}
