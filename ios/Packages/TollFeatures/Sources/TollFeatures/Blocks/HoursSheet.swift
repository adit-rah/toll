import SwiftUI
import TollCore
import TollUI

/// Hours (the design canvas): from, until, and the days a block starts on.
struct HoursSheet: View {
  @State private var rule: WeeklySchedule.Rule
  let done: (WeeklySchedule.Rule) -> Void
  @Environment(\.dismiss) private var dismiss

  init(rule: WeeklySchedule.Rule, done: @escaping (WeeklySchedule.Rule) -> Void) {
    _rule = State(initialValue: rule)
    self.done = done
  }

  var body: some View {
    VStack(alignment: .leading, spacing: TollSpacing.groupGap) {
      Text(Copy.Blocks.hours).font(TollFont.title).foregroundStyle(TollColor.label)
        .accessibilityAddTraits(.isHeader)
      Card {
        DatePicker(
          Copy.Blocks.from, selection: clockBinding(rule.window.start) { rule.window.start = $0 },
          displayedComponents: .hourAndMinute
        )
        .frame(minHeight: 52)
        DatePicker(
          Copy.Blocks.until, selection: clockBinding(rule.window.end) { rule.window.end = $0 },
          displayedComponents: .hourAndMinute
        )
        .frame(minHeight: 52)
      }
      .font(TollFont.body)
      Text(Copy.Blocks.days).font(TollFont.captionMedium).foregroundStyle(TollColor.label2)
      HStack(spacing: 6) {
        ForEach(Weekday.allCases, id: \.self) { day in
          let on = rule.days.contains(day)
          Button {
            if on { rule.days.remove(day) } else { rule.days.insert(day) }
          } label: {
            Text(Copy.Blocks.dayLetter(day))
              .font(TollFont.subheadSemibold)
              .frame(maxWidth: .infinity, minHeight: 44)
              .foregroundStyle(on ? TollColor.onAccent : TollColor.label)
              .background(on ? TollColor.accent : TollColor.surface, in: Circle())
          }
          .accessibilityLabel(Copy.Home.shortDay(day))
          .accessibilityAddTraits(on ? .isSelected : [])
        }
      }
      .tollHaptic(.selection, trigger: rule.days)
      Spacer(minLength: 0)
      PrimaryButton(Copy.Blocks.done) {
        done(rule)
        dismiss()
      }
      .disabled(rule.days.isEmpty || !rule.window.isValid)
    }
    .tollGutter()
    .padding(.top, TollSpacing.titleGap)
    .padding(.bottom, TollSpacing.footerBottom)
    .background(TollColor.bg)
    .presentationDetents([.medium, .large])
  }
}
