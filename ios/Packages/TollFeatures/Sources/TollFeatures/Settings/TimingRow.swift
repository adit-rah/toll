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
      Button(action: useHealth) {
        SettingsRow(Copy.Timing.row, detail: setting.detail, symbol: .timing) {
          HStack(spacing: 6) {
            Image(symbol: .health).unredacted()
              .tollGlyph(13, weight: .semibold)
              .accessibilityHidden(true)
            Text(Copy.Fit.useHealth)
          }
          .tollType(.link, TollColor.accent)
        }
      }
      .buttonStyle(.tollPressable)
    } else {
      Toggle(isOn: $on) {
        HStack(spacing: TollSpacing.rowGap) {
          IconTile(.timing, accent: false)
          // This week's start while it's on as saved; what it does once the switch has moved.
          RowText(
            title: Copy.Timing.row,
            detail: on == (setting.kind == .on) ? setting.detail : setting.about)
        }
      }
      .tint(TollColor.accent)
      .padding(.vertical, 8)
      .frame(minHeight: 60)
    }
  }
}
