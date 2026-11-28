import SwiftUI
import TollCore
import TollUI

/// Your sleep (#144): found in Health ("You usually fall asleep around 11:20 pm and wake around
/// 7:10 am") or asked, on the same screen. Drawn moon to sun; both ends change on their rows, and
/// Fri and Sat nights get their own when they differ. Shared by onboarding and the one-time flow.
struct SleepTimesStep: View {
  @Bindable var draft: FitDraft
  let next: () -> Void

  var body: some View {
    SetupPage(title: title) {
      if let picture = NightPicture(.everyDay(draft.window), now: Date(), calendar: .current) {
        NightPictureView(picture: picture).padding(.top, 24)
      }
      SleepTimesCard(draft: draft).padding(.top, 20)
      // Health's tile on the times it found, so found and asked differ without the words (#76).
      Footnote(note, symbol: draft.estimate == nil ? nil : .health)
        .padding(.top, TollSpacing.underCard)
    } actions: {
      PrimaryButton(Copy.Setup.continue, action: next)
        .disabled(!draft.schedule.isValid)
    }
  }

  /// What Health said, not what the rows now hold: the rows and the picture show those.
  private var title: String {
    guard let usual = draft.estimate?.usual else { return Copy.Fit.ask }
    return Copy.Fit.found(asleep: Copy.time(usual.asleep), wake: Copy.time(usual.wake))
  }

  private var note: String {
    guard let estimate = draft.estimate else {
      return draft.health ? Copy.Fit.askAfterHealth : Copy.Fit.askNote
    }
    let found = Copy.Fit.foundNote(estimate.nights)
    return estimate.weekends == nil ? found : found + " " + Copy.Fit.weekendsFound
  }
}

/// Falling asleep and waking, each with its glyph and a time, and Fri and Sat nights apart when
/// they differ. A change shows at once in the picture above.
struct SleepTimesCard: View {
  @Bindable var draft: FitDraft

  var body: some View {
    Card {
      TimeRow(
        title: Copy.Fit.fallAsleep, detail: weeknights, symbol: .sleep, time: draft.asleep
      ) { draft.asleep = $0 }
      TimeRow(title: Copy.Fit.wakeUp, detail: weeknights, symbol: .sun, time: draft.wake) {
        draft.wake = $0
      }
      CardRow(Copy.Setup.differentOnWeekends, size: .list) {
        IconTile(.weekends, accent: false)
      } trailing: {
        Toggle(Copy.Setup.differentOnWeekends, isOn: $draft.weekendsDiffer)
          .labelsHidden()
          .tint(TollColor.accent)
      }
      if draft.weekendsDiffer {
        TimeRow(
          title: Copy.Fit.fallAsleep, detail: Copy.Setup.weekendNights, symbol: .sleep,
          time: draft.weekendAsleep
        ) { draft.weekendAsleep = $0 }
        TimeRow(
          title: Copy.Fit.wakeUp, detail: Copy.Setup.weekendNights, symbol: .sun,
          time: draft.weekendWake
        ) { draft.weekendWake = $0 }
      }
    }
    .animation(Motion.stateChange, value: draft.weekendsDiffer)
  }

  private var weeknights: String? { draft.weekendsDiffer ? Copy.Setup.weeknights : nil }
}

/// A time on a row: the system's compact picker, which opens its wheel, read out with the row's
/// title.
struct TimeRow: View {
  let title: String
  var detail: String?
  let symbol: TollSymbol
  let time: ClockTime
  let set: (ClockTime) -> Void

  var body: some View {
    CardRow(title, detail: detail, size: .list) {
      IconTile(symbol)
    } trailing: {
      DatePicker(title, selection: clockBinding(time, set), displayedComponents: .hourAndMinute)
        .labelsHidden()
        .tint(TollColor.accent)
        .accessibilityLabel([title, detail].compactMap { $0 }.joined(separator: ", "))
    }
  }
}

/// A time picker works in dates; the model in wall-clock times.
func clockBinding(_ time: ClockTime, _ set: @escaping (ClockTime) -> Void) -> Binding<Date> {
  Binding(
    get: {
      Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date())
        ?? Date()
    },
    set: { date in
      let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
      set(ClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0))
    })
}
