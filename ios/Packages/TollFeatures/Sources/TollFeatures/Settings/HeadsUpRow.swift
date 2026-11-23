import SwiftUI
import TollCore
import TollUI

/// Settings' heads-up switch (D68, #104). Turning it on asks iOS the first time. Once iOS has said
/// no, only iOS Settings can change that, so the row says so and leaves for it, like Screen Time's.
struct HeadsUpRow: View {
  let model: AppModel

  var body: some View {
    if model.notifications == .denied {
      Button(action: openSystemSettings) {
        SettingsRow(Copy.HeadsUp.row, detail: Copy.HeadsUp.rowDenied) {
          HStack(spacing: 6) {
            Text(Copy.HeadsUp.openSettings)
            Image(symbol: .openSettings).unredacted()
              .font(.system(size: 13, weight: .semibold))
              .accessibilityHidden(true)
          }
          .tollType(.link, TollColor.accent)
        }
      }
      .buttonStyle(.plain)
    } else {
      Toggle(isOn: on) {
        RowText(
          title: Copy.HeadsUp.row,
          detail: Copy.HeadsUp.rowDetail(minutes: model.config.headsUp.leadMinutes))
      }
      .tint(TollColor.accent)
      .padding(.vertical, 8)
      .frame(minHeight: 54)
    }
  }

  /// On only when it can arrive: switched on here and allowed by iOS.
  private var on: Binding<Bool> {
    Binding(
      get: { model.state.headsUp && model.notifications == .allowed },
      set: { on in
        if on {
          Task { await model.turnOnHeadsUp() }
        } else {
          model.turnOffHeadsUp()
        }
      })
  }
}
