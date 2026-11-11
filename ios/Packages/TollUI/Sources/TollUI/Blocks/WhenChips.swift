import SwiftUI
import TollCore

/// Design §3.16. Four tiles in a 2×2 grid, 88 pt at standard text sizes. The caller preselects Always.
/// Custom calls `onCustom` (which opens Custom hours) instead of selecting; set the selection to
/// `.custom` when that sheet's Done returns, and pass the chosen schedule so the tile shows its window.
public struct WhenChips: View {
  @Binding var selection: Schedule.Kind
  let customSchedule: Schedule?
  let tileFill: Color
  let onCustom: (() -> Void)?

  /// `tileFill` is the unselected fill. The default reads on `bg` (white `surface` would vanish there);
  /// pass `surface` on grouped backgrounds, where the default would vanish instead.
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
    Grid(horizontalSpacing: TollSpacing.tileGap, verticalSpacing: TollSpacing.tileGap) {
      GridRow {
        tile(.always)
        tile(.nights)
      }
      GridRow {
        tile(.weekdays)
        tile(.custom)
      }
    }
    // Tiles fill their row so a pair stays the same height, which would also let the grid take every
    // spare point on the screen; its ideal height is the size the design means.
    .fixedSize(horizontal: false, vertical: true)
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
      VStack(alignment: .leading, spacing: 8) {
        Image(systemName: Self.symbol(for: kind))
          .font(TollFont.body)
          .frame(height: 24)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 0) {
          Text(text.title)
            .font(TollFont.subheadSemibold)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
          Text(text.detail)
            .font(TollFont.detail)
            .monospacedDigit()
            .foregroundStyle(isSelected ? TollColor.onAccent.opacity(0.8) : TollColor.label2)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
        }
      }
      .foregroundStyle(isSelected ? TollColor.onAccent : TollColor.label)
      .padding(.horizontal, 12)
      .padding(.vertical, 14)
      .frame(
        maxWidth: .infinity, minHeight: TollSpacing.tileHeight, maxHeight: .infinity,
        alignment: .topLeading
      )
      .background(
        isSelected ? TollColor.accent : tileFill,
        in: RoundedRectangle(cornerRadius: TollRadius.tile, style: .continuous)
      )
      .contentShape(RoundedRectangle(cornerRadius: TollRadius.tile, style: .continuous))
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
