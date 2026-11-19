import SwiftUI
import TollCore
import TollUI

/// The sleep window, edited the way setup set it. During a block the edit waits (B-3).
struct WindowSettingsView: View {
  let model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var wake = Date()
  @State private var start = Date()

  var body: some View {
    Form {
      Section {
        DatePicker(Copy.Settings.wake, selection: $wake, displayedComponents: .hourAndMinute)
        DatePicker(Copy.Settings.start, selection: $start, displayedComponents: .hourAndMinute)
      } footer: {
        Text(Copy.Settings.changesLater)
      }
    }
    .navigationTitle(Copy.Settings.window)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button(Copy.Settings.save) {
          guard var sleep = model.sleepDraft else { return }
          sleep.schedule = .everyDay(
            TimeWindow(start: ClockTime(date: start), end: ClockTime(date: wake)))
          model.save(sleep)
          dismiss()
        }
        .disabled(!TimeWindow(start: ClockTime(date: start), end: ClockTime(date: wake)).isValid)
      }
    }
    .onAppear {
      let window =
        model.sleepDraft?.schedule.windows.first
        ?? TimeWindow(wake: ClockTime(hour: 7), leadHours: model.config.window.leadHours)
      wake = window.end.date()
      start = window.start.date()
    }
  }
}

extension ClockTime {
  init(date: Date, calendar: Calendar = .current) {
    let parts = calendar.dateComponents([.hour, .minute], from: date)
    self.init(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
  }

  /// Today at this time, for a time picker.
  func date(calendar: Calendar = .current) -> Date {
    calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
  }
}
