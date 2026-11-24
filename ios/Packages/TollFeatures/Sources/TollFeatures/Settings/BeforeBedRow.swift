import SwiftUI
import TollCore
import TollUI

/// Settings › Before bed (D76): how long before bed apps lock, growing with the person or fixed.
/// The row says now and next; a tap opens the sheet.
struct BeforeBedRow: View {
  let model: AppModel
  @State private var editing = false

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
/// night is on applies from tomorrow night (B-3), and the sheet says so.
struct BeforeBedSheet: View {
  let model: AppModel
  let close: () -> Void
  private let now: BeforeBed
  @State private var grows: Bool
  @State private var minutes: Int

  init(model: AppModel, close: @escaping () -> Void) {
    self.model = model
    self.close = close
    now = BeforeBed(state: model.state, config: model.config)
    _grows = State(initialValue: now.grows)
    _minutes = State(initialValue: now.minutes)
  }

  var body: some View {
    let gap = model.config.gap
    SheetPage(height: 520) {
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
    } actions: {
      PrimaryButton(Copy.Gap.done) {
        model.setGap(now.choice(grows: grows, fixed: minutes, config: model.config))
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
