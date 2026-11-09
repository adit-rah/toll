import SwiftUI
import TollCore

/// Design §3.16. Four 88 pt tiles in a 2×2 grid. The caller preselects Always. Custom calls `onCustom`
/// (which opens Custom hours) instead of selecting; set the selection to `.custom` when that sheet's
/// Done returns, and pass the chosen schedule so the tile shows its window.
public struct WhenChips: View {
  @Binding var selection: Schedule.Kind
  let customSchedule: Schedule?
  let tileFill: Color
  let onCustom: (() -> Void)?

  /// `tileFill` is the unselected fill. The default reads on `bg` (white `surface` would vanish there);
  /// pass `surface` on grouped backgrounds.
  public init(
    selection: Binding<Schedule.Kind>, customSchedule: Schedule? = nil,
    tileFill: Color = TollColor.surfaceRaised, onCustom: (() -> Void)? = nil
  ) {
    _selection = selection
    self.customSchedule = customSchedule
    self.tileFill = tileFill
    self.onCustom = onCustom
  }

  public var body: some View {
    Grid(horizontalSpacing: 10, verticalSpacing: 10) {
      GridRow {
        tile(.always)
        tile(.nights)
      }
      GridRow {
        tile(.weekdays)
        tile(.custom)
      }
    }
    .tollHaptic(.selection, trigger: selection)
  }

  private func tile(_ kind: Schedule.Kind) -> some View {
    let text = Self.text(for: kind, custom: customSchedule)
    let isSelected = selection == kind
    return Button {
      if kind == .custom, let onCustom {
        onCustom()
      } else {
        selection = kind
      }
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        Image(systemName: Self.symbol(for: kind))
          .font(TollFont.body)
          .accessibilityHidden(true)
        Spacer(minLength: 8)
        Text(text.title).font(TollFont.subheadSemibold)
        Text(text.detail)
          .font(TollFont.micro)
          .monospacedDigit()
          .foregroundStyle(isSelected ? TollColor.onAccent : TollColor.label2)
      }
      .foregroundStyle(isSelected ? TollColor.onAccent : TollColor.label)
      .padding(12)
      .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
      .background(
        isSelected ? TollColor.accent : tileFill,
        in: RoundedRectangle(cornerRadius: TollRadius.button, style: .continuous)
      )
      .animation(Motion.stateChange, value: isSelected)
      .accessibilityElement(children: .combine)
    }
    .buttonStyle(TileStyle())
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  static func text(for kind: Schedule.Kind, custom: Schedule?) -> (title: String, detail: String) {
    switch kind {
    case .always: return Copy.Schedules.alwaysTile
    case .nights: return Copy.Schedules.nightsTile
    case .weekdays: return Copy.Schedules.weekdaysTile
    case .custom:
      guard let custom, custom.kind == .custom else { return Copy.Schedules.customTile }
      return (Copy.Schedules.customTile.0, Copy.Schedules.window(custom))
    }
  }

  static func symbol(for kind: Schedule.Kind) -> String {
    switch kind {
    case .always: "infinity"
    case .nights: "moon"
    case .weekdays: "sun.max"
    case .custom: "clock"
    }
  }
}

/// Pressed tiles sit at 0.98 and return to 1 on release; Reduce Motion keeps them still.
private struct TileStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .reducibleScale(configuration.isPressed ? 0.98 : 1)
      .animation(Motion.stateChange, value: configuration.isPressed)
  }
}
