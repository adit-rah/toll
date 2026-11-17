import SwiftUI
import TollCore
import TollUI

/// Setup 2 (spec §7): the wake time sets the night; its start can be moved on its own.
struct WakeTimeView: View {
  let model: SetupModel
  @State private var editingStart = false

  var body: some View {
    SetupPage(step: SetupModel.Step.wake.number, title: Copy.Setup.wakeTitle) {
      DatePicker(
        Copy.Setup.wakeTitle, selection: binding(model.wake, model.setWake),
        displayedComponents: .hourAndMinute
      )
      .datePickerStyle(.wheel)
      .labelsHidden()
      .frame(maxWidth: .infinity)
      HStack(alignment: .firstTextBaseline) {
        SetupLine(Copy.Setup.nights(model.window))
        Button(Copy.Setup.changeStart) { editingStart.toggle() }
          .buttonStyle(.tollQuiet)
      }
      if editingStart {
        DatePicker(
          Copy.Setup.nightsStart, selection: binding(model.start, model.setStart),
          displayedComponents: .hourAndMinute
        )
        .tollText(.body)
      }
    } actions: {
      PrimaryButton(Copy.Setup.continue) { model.go(.home) }
        .disabled(!model.window.isValid)
    }
  }

  private func binding(_ time: ClockTime, _ set: @escaping (ClockTime) -> Void) -> Binding<Date> {
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
}
