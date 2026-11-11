import SwiftUI
import TollCore
import TollUI

/// Custom hours (design §4.6): From and Until, then the days. The times are the system's compact
/// pickers in two rows: two wheels side by side do not fit a phone's width without clipping each other.
struct CustomHoursSheet: View {
  @Binding var schedule: Schedule
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var from = Date()
  @State private var until = Date()
  @State private var days: Set<Weekday> = Weekday.all

  private let calendar = Calendar.current
  private static let sheetHeight: CGFloat = 380

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(Copy.Schedules.custom).tollText(.title)
      VStack(spacing: 0) {
        timeRow(Copy.Schedules.from, $from)
        Hairline()
        timeRow(Copy.Schedules.until, $until)
      }
      .padding(.horizontal, TollSpacing.cardPadding)
      .background(TollColor.fill, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
      HStack(spacing: 6) {
        ForEach(Weekday.allCases, id: \.self) { day in
          dayTile(day)
        }
      }
      Spacer(minLength: 0)
      PrimaryButton(Copy.BlockEditor.done) {
        schedule = .custom(start: clock(from), end: clock(until), days: days.isEmpty ? Weekday.all : days)
        dismiss()
      }
    }
    .tollGutter()
    .padding(.top, TollSpacing.titleGap)
    .padding(.bottom, TollSpacing.footerBottom)
    .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.height(Self.sheetHeight)])
    .presentationDragIndicator(.visible)
    .onAppear {
      from = date(schedule.kind == .custom ? schedule.start : ClockTime(hour: 22))
      until = date(schedule.kind == .custom ? schedule.end : ClockTime(hour: 7))
      if schedule.kind == .custom { days = schedule.days }
    }
  }

  private func timeRow(_ title: String, _ value: Binding<Date>) -> some View {
    DatePicker(title, selection: value, displayedComponents: .hourAndMinute)
      .font(TollFont.body)
      .foregroundStyle(TollColor.label)
      .frame(minHeight: TollSpacing.rowMinHeight)
  }

  private func dayTile(_ day: Weekday) -> some View {
    let on = days.contains(day)
    return Button {
      Haptics.selection()
      if on { days.remove(day) } else { days.insert(day) }
    } label: {
      Text(calendar.veryShortStandaloneWeekdaySymbols[day.rawValue % 7])
        .font(TollFont.subheadMedium)
        .foregroundStyle(on ? TollColor.onAccent : TollColor.label)
        .frame(maxWidth: .infinity, minHeight: TollSpacing.minTapTarget)
        .background(
          on ? TollColor.accent : TollColor.fill,
          in: RoundedRectangle(cornerRadius: TollRadius.chip, style: .continuous)
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(calendar.standaloneWeekdaySymbols[day.rawValue % 7])
    .accessibilityAddTraits(on ? .isSelected : [])
  }

  private func clock(_ date: Date) -> ClockTime {
    let c = calendar.dateComponents([.hour, .minute], from: date)
    return ClockTime(hour: c.hour ?? 0, minute: c.minute ?? 0)
  }

  private func date(_ time: ClockTime) -> Date {
    calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
  }
}
