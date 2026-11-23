import SwiftUI
import TollCore
import TollUI

/// A block's hours, changed in place on the editor's card (#89) rather than in a sheet: From and
/// Until open Apple's time wheel by the field, and the days are chips. A change that would make a
/// ninth time window is said under the card and keeps Save off (D40).
struct HoursInline: View {
  let title: String
  let rule: WeeklySchedule.Rule
  let set: (WeeklySchedule.Rule) -> Void
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: TollSpacing.rowGap) {
        IconTile(.hours, accent: false)
        Text(title).tollType(.rowTitle, TollColor.label)
      }
      // Side by side; stacked at accessibility sizes so a time never wraps.
      let layout =
        typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
        : AnyLayout(HStackLayout(alignment: .bottom, spacing: 12))
      layout {
        TimeField(label: Copy.Blocks.from, time: rule.window.start) { start in
          var next = rule
          next.window.start = start
          set(next)
        }
        if !typeSize.isAccessibilitySize {
          Text("–").tollType(.bar, TollColor.label2).frame(height: 56).accessibilityHidden(true)
        }
        TimeField(label: Copy.Blocks.until, time: rule.window.end) { end in
          var next = rule
          next.window.end = end
          set(next)
        }
      }
      DayChips(days: rule.days) { days in
        var next = rule
        next.days = days
        set(next)
      }
    }
    .padding(.vertical, 12)
  }
}

/// Seven chips, Monday first, the chosen days amber. Wordless, the chips still show which of the
/// week's seven places are on.
private struct DayChips: View {
  let days: Set<Weekday>
  let set: (Set<Weekday>) -> Void

  var body: some View {
    HStack(spacing: 6) {
      ForEach(Weekday.allCases, id: \.self) { day in
        let on = days.contains(day)
        Button {
          set(on ? days.subtracting([day]) : days.union([day]))
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
    .tollHaptic(.selection, trigger: days)
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
