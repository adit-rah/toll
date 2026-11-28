import SwiftUI
import TollCore
import TollUI

/// Settings › Sleep's switch for personal timing (#171, D65), applied with the screen's Save.
/// The model learns only from Health's sleep, so without Health the row offers Health instead
/// of a switch that couldn't do anything.
struct TimingRow: View {
  let setting: TimingSetting
  @Binding var on: Bool
  let useHealth: () -> Void

  var body: some View {
    if setting.kind == .needsHealth {
      // The link under the words, as a card's action, so neither the title nor the link is
      // squeezed into a column beside the other.
      HStack(alignment: .top, spacing: TollSpacing.rowGap) {
        IconTile(.timing, accent: false)
        VStack(alignment: .leading, spacing: 0) {
          RowText(title: Copy.Timing.row, detail: setting.detail)
          Button(action: useHealth) {
            HStack(spacing: 6) {
              Image(symbol: .health).unredacted()
                .tollGlyph(13, weight: .semibold)
                .accessibilityHidden(true)
              Text(Copy.Fit.useHealth)
            }
            .tollType(.link, TollColor.accent)
            .frame(minHeight: TollSpacing.minTapTarget)
          }
          .buttonStyle(.tollPressable)
        }
      }
      .padding(.top, 12)
    } else {
      // A card row, so at accessibility sizes the switch goes under the words, as weekends' does.
      // This week's start while it's on as saved; what it does once the switch has moved.
      CardRow(
        Copy.Timing.row, detail: on == (setting.kind == .on) ? setting.detail : setting.about,
        size: .list
      ) {
        IconTile(.timing, accent: false)
      } trailing: {
        Toggle(Copy.Timing.row, isOn: $on)
          .labelsHidden()
          .tint(TollColor.accent)
      }
    }
  }
}
