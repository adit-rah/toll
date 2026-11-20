import SwiftUI
import TollCore
import TollUI

/// Block · hours (the canvas): From and Until as two 56 pt fields that open Apple's time picker, the
/// days, and how many time windows the blocks use (D40). Done is off for a change that would make a
/// ninth window.
struct HoursSheet: View {
  @State private var rule: WeeklySchedule.Rule
  let limits: (WeeklySchedule.Rule) -> BlockLimits
  let done: (WeeklySchedule.Rule) -> Void
  @Environment(\.dismiss) private var dismiss

  init(
    rule: WeeklySchedule.Rule, limits: @escaping (WeeklySchedule.Rule) -> BlockLimits,
    done: @escaping (WeeklySchedule.Rule) -> Void
  ) {
    _rule = State(initialValue: rule)
    self.limits = limits
    self.done = done
  }

  var body: some View {
    let limits = limits(rule)
    let over = limits.windowsUsed > limits.windowsMax
    SheetPage(height: 484) {
      SheetTitle(Copy.Blocks.hours)
      HStack(alignment: .bottom, spacing: 12) {
        TimeField(label: Copy.Blocks.from, time: rule.window.start) { rule.window.start = $0 }
        Text("–").tollType(.bar, TollColor.label2).frame(height: 56).accessibilityHidden(true)
        TimeField(label: Copy.Blocks.until, time: rule.window.end) { rule.window.end = $0 }
      }
      .padding(.top, 20)
      Text(Copy.Blocks.days).tollType(.eyebrow, TollColor.label2).padding(.top, 24)
      HStack(spacing: 6) {
        ForEach(Weekday.allCases, id: \.self) { day in
          let on = rule.days.contains(day)
          Button {
            if on { rule.days.remove(day) } else { rule.days.insert(day) }
          } label: {
            Text(Copy.Blocks.dayLetter(day))
              .tollType(.action, on ? TollColor.onAccent : TollColor.label2)
              .frame(maxWidth: .infinity, minHeight: 42)
              .background(
                on ? TollColor.accent : TollColor.surfaceRaised,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(Copy.Home.shortDay(day))
          .accessibilityAddTraits(on ? .isSelected : [])
        }
      }
      .padding(.top, 10)
      .tollHaptic(.selection, trigger: rule.days)
      Text(
        over
          ? Copy.Blocks.windowsFull(limits.windowsMax)
          : Copy.Blocks.windowsUsed(limits.windowsUsed, of: limits.windowsMax)
      )
      .tollType(.detail, over ? TollColor.warn : TollColor.label2)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.top, 14)
    } actions: {
      PrimaryButton(Copy.Blocks.done) {
        done(rule)
        dismiss()
      }
      .disabled(rule.days.isEmpty || !rule.window.isValid || over)
    }
  }
}

/// "FROM" over a 56 pt field showing the time; tapping it opens Apple's time wheel in a popover by
/// the field, so the field keeps the board's look.
private struct TimeField: View {
  let label: String
  let time: ClockTime
  let set: (ClockTime) -> Void
  @State private var editing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .tollType(
          TollType(
            size: 12, lineHeight: 16, weight: .semibold, style: .caption, tracking: 0.6,
            uppercase: true)
        )
        .foregroundStyle(TollColor.label2)
        .accessibilityHidden(true)
      Button {
        editing = true
      } label: {
        Text(Copy.time(time))
          .tollType(
            TollType(size: 22, lineHeight: 28, weight: .semibold, style: .title2, tabular: true)
          )
          .foregroundStyle(TollColor.label)
          .frame(maxWidth: .infinity, minHeight: 56)
          .background(
            TollColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(label), \(Copy.time(time))")
      .popover(isPresented: $editing) {
        DatePicker(label, selection: clockBinding(time, set), displayedComponents: .hourAndMinute)
          .datePickerStyle(.wheel)
          .labelsHidden()
          .padding(12)
          .presentationCompactAdaptation(.popover)
      }
    }
  }
}
