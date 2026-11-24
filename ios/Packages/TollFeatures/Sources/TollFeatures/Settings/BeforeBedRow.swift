import SwiftUI
import TollCore
import TollUI

/// Settings › Before bed (D76): how long before bed apps lock, growing with the person or fixed,
/// and the helpers Tonight offers in that time (D80). The row says now and next; a tap opens the
/// sheet. One row for both: they're the same minutes.
struct BeforeBedRow: View {
  let model: AppModel
  @State private var editing = false

  init(model: AppModel) {
    self.model = model
    #if DEBUG
      // The sheet's own render (docs/renders.md).
      _editing = State(initialValue: DemoScenario.current == .settingsBeforeBed)
    #endif
  }

  var body: some View {
    Button {
      editing = true
    } label: {
      SettingsRow(Copy.Gap.row, detail: BeforeBed(state: model.state, config: model.config).detail)
      {
        Chevron()
      }
    }
    .buttonStyle(.plain)
    .sheet(isPresented: $editing) {
      BeforeBedSheet(model: model) { editing = false }
    }
  }
}

/// Two choices, each with what it does, and the fixed gap's minutes in steps. A change while the
/// night is on applies from tomorrow night (B-3), and the sheet says so. Under them, the helpers'
/// switch and the breathing tone's length (D80), which apply at once.
struct BeforeBedSheet: View {
  let model: AppModel
  let close: () -> Void
  private let now: BeforeBed
  @State private var grows: Bool
  @State private var minutes: Int
  @State private var helpers: Bool
  @State private var breath: Int

  init(model: AppModel, close: @escaping () -> Void) {
    self.model = model
    self.close = close
    now = BeforeBed(state: model.state, config: model.config)
    _grows = State(initialValue: now.grows)
    _minutes = State(initialValue: now.minutes)
    _helpers = State(initialValue: model.state.helpers.on)
    _breath = State(initialValue: model.breathMinutes)
  }

  var body: some View {
    let gap = model.config.gap
    SheetPage(height: 700) {
      SheetTitle(Copy.Gap.sheetTitle)
      SheetBody(Copy.Gap.sheetBody)
      // Rows on the sheet itself: a card would vanish into the sheet's own surface.
      VStack(spacing: 0) {
        option(
          Copy.Gap.grows, detail: Copy.Gap.growsOption(step: gap.step, cap: gap.cap),
          chosen: grows
        ) { grows = true }
        Hairline()
        option(Copy.Gap.fixed, detail: Copy.Gap.fixedOption, chosen: !grows) { grows = false }
        if !grows {
          Hairline()
          Stepper(value: $minutes, in: 0...gap.manualMax, step: gap.manualStep) {
            Text(Copy.Gap.beforeBed(minutes)).tollType(.rowTitle, TollColor.label)
          }
          .padding(.vertical, 8)
          .frame(minHeight: 54)
        }
      }
      .padding(.top, 20)
      if now.nightOn {
        Footnote(Copy.Gap.tonightStays).padding(.top, 12)
      }
      VStack(spacing: 0) {
        Toggle(isOn: $helpers) {
          RowText(title: Copy.Helpers.setting, detail: Copy.Helpers.settingDetail)
        }
        .tint(TollColor.accent)
        .padding(.vertical, 8)
        .frame(minHeight: 54)
        if helpers {
          Hairline()
          Stepper(value: $breath, in: model.config.helpers.breathRange) {
            HStack(spacing: 8) {
              Image(symbol: .breathe).unredacted()
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(TollColor.label2)
                .accessibilityHidden(true)
              Text(Copy.Helpers.breathLength(breath)).tollType(.rowTitle, TollColor.label)
            }
          }
          .padding(.vertical, 8)
          .frame(minHeight: 54)
        }
      }
      .padding(.top, 24)
    } actions: {
      PrimaryButton(Copy.Gap.done) {
        model.setBeforeBed(
          now.choice(grows: grows, fixed: minutes, config: model.config),
          helpers: Helpers(on: helpers, breathMinutes: breath))
        close()
      }
    }
    .tollHaptic(.selection, trigger: grows)
  }

  /// A choice as a row, its tick saying which is chosen, never colour alone.
  private func option(
    _ title: String, detail: String, chosen: Bool, pick: @escaping () -> Void
  ) -> some View {
    Button(action: pick) {
      AdaptiveStack(spacing: TollSpacing.rowGap) {
        RowText(title: title, detail: detail)
        Image(symbol: .done).unredacted()
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(TollColor.accent)
          .opacity(chosen ? 1 : 0)
          .accessibilityHidden(true)
      }
      .padding(.vertical, 8)
      .frame(minHeight: 54)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(chosen ? .isSelected : [])
  }
}
