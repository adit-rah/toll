import SwiftUI
import TollCore
import TollUI

/// Setup 1 (the canvas): the wake time sets the night (8 h 30 m earlier); its start can be moved, and
/// weekends can wake later.
struct WakeTimeView: View {
  @Bindable var model: SetupModel
  @State private var editingStart = false

  var body: some View {
    SetupPage(step: SetupModel.Step.wake.number, title: Copy.Setup.wakeTitle) {
      WakeWheel(label: Copy.Setup.wakeTitle, time: model.wake, set: model.setWake)
      Card {
        CardRow(Copy.Setup.yourNights, detail: Copy.Setup.nights(model.window)) {
          IconTile("moon.fill")
        } trailing: {
          Button(Copy.Setup.change) { editingStart.toggle() }
            .buttonStyle(.tollQuiet)
        }
        if editingStart {
          DatePicker(
            Copy.Setup.nightsStart, selection: clockBinding(model.start, model.setStart),
            displayedComponents: .hourAndMinute
          )
          .font(TollFont.body)
          .frame(minHeight: 52)
        }
        CardRow(Copy.Setup.differentOnWeekends) {
          IconTile("calendar", accent: false)
        } trailing: {
          Toggle(Copy.Setup.differentOnWeekends, isOn: $model.weekendsDiffer)
            .labelsHidden()
            .tint(TollColor.accent)
        }
        if model.weekendsDiffer {
          DatePicker(
            Copy.Setup.weekendWake,
            selection: clockBinding(model.weekendWake, model.setWeekendWake),
            displayedComponents: .hourAndMinute
          )
          .font(TollFont.body)
          .frame(minHeight: 52)
          CardRow(Copy.Setup.weekendNights, detail: Copy.Setup.nights(model.weekendWindow)) {
            IconTile("moon.stars.fill", accent: false)
          }
        }
      }
      .animation(Motion.stateChange, value: model.weekendsDiffer)
      .animation(Motion.stateChange, value: editingStart)
      Footnote(Copy.Setup.sleepAdvice)
    } actions: {
      PrimaryButton(Copy.Setup.continue) { model.go(.home) }
        .disabled(!model.schedule.isValid)
    }
  }
}

/// The system's wheel, centred, read out by its question.
struct WakeWheel: View {
  let label: String
  let time: ClockTime
  let set: (ClockTime) -> Void

  var body: some View {
    DatePicker(label, selection: clockBinding(time, set), displayedComponents: .hourAndMinute)
      .datePickerStyle(.wheel)
      .labelsHidden()
      .frame(maxWidth: .infinity)
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
