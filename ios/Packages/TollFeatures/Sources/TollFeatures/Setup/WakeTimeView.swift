import SwiftUI
import TollCore
import TollUI
import UIKit

/// Setup 1 (the canvas's Wake time, and Wake time · weekends on): the wake time sets the night (8 h
/// 30 m earlier). "Change" on a night opens its own time under it: the start of weeknights, the wake
/// time of weekends.
struct WakeTimeView: View {
  @Bindable var model: SetupModel
  @State private var editing: Night?

  enum Night {
    case nights, weekends
  }

  var body: some View {
    SetupPage(step: SetupModel.Step.wake.number, title: Copy.Setup.wakeTitle) {
      WakeWheel(label: Copy.Setup.wakeTitle, time: model.wake, set: model.setWake)
        .padding(.top, model.weekendsDiffer ? 24 : 32)
      Card {
        nightRow(
          title: model.weekendsDiffer ? Copy.Setup.weeknights : Copy.Setup.yourNights,
          detail: model.weekendsDiffer
            ? Copy.span(model.window) : Copy.Setup.nights(model.window),
          night: .nights)
        if editing == .nights {
          InlineTime(
            label: Copy.Setup.nightsStart, time: model.start, set: model.setStart)
        }
        CardRow(Copy.Setup.differentOnWeekends, size: .list) {
          IconTile("calendar", accent: false)
        } trailing: {
          Toggle(Copy.Setup.differentOnWeekends, isOn: $model.weekendsDiffer)
            .labelsHidden()
            .tint(TollColor.accent)
        }
        if model.weekendsDiffer {
          nightRow(
            title: Copy.Setup.weekendNights, detail: Copy.span(model.weekendWindow),
            night: .weekends)
          if editing == .weekends {
            InlineTime(
              label: Copy.Setup.weekendWake, time: model.weekendWake, set: model.setWeekendWake)
          }
        }
      }
      .padding(.top, model.weekendsDiffer ? 24 : 32)
      .animation(Motion.stateChange, value: model.weekendsDiffer)
      .animation(Motion.stateChange, value: editing)
      Footnote(Copy.Setup.sleepAdvice).padding(.top, TollSpacing.underCard)
    } actions: {
      PrimaryButton(Copy.Setup.continue) { model.go(.home) }
        .disabled(!model.schedule.isValid)
    }
  }

  private func nightRow(title: String, detail: String, night: Night) -> some View {
    CardRow(title, detail: detail, size: .night) {
      IconTile("moon")
    } trailing: {
      Button(Copy.Setup.change) { editing = editing == night ? nil : night }
        .tollType(.link, TollColor.accent)
        .frame(minWidth: TollSpacing.minTapTarget, minHeight: TollSpacing.minTapTarget)
    }
  }
}

/// A time inside the card, under the row it changes.
private struct InlineTime: View {
  let label: String
  let time: ClockTime
  let set: (ClockTime) -> Void

  var body: some View {
    DatePicker(label, selection: clockBinding(time, set), displayedComponents: .hourAndMinute)
      .tollType(.rowTitle, TollColor.label)
      .frame(minHeight: RowSize.compact.minHeight)
  }
}

/// Apple's time wheel in 15-minute steps, as the board draws it, read out by its question. SwiftUI's
/// picker has no minute interval, so this is UIKit's.
struct WakeWheel: UIViewRepresentable {
  let label: String
  let time: ClockTime
  let set: (ClockTime) -> Void

  func makeUIView(context: Context) -> UIDatePicker {
    let picker = UIDatePicker()
    picker.datePickerMode = .time
    picker.preferredDatePickerStyle = .wheels
    picker.minuteInterval = 15
    picker.accessibilityLabel = label
    picker.addTarget(
      context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
    picker.setContentHuggingPriority(.defaultLow, for: .horizontal)
    return picker
  }

  func updateUIView(_ picker: UIDatePicker, context: Context) {
    context.coordinator.set = set
    let date = clockBinding(time, set).wrappedValue
    if picker.date != date { picker.setDate(date, animated: false) }
  }

  func makeCoordinator() -> Coordinator { Coordinator(set: set) }

  @MainActor final class Coordinator: NSObject {
    var set: (ClockTime) -> Void

    init(set: @escaping (ClockTime) -> Void) {
      self.set = set
    }

    @objc func changed(_ picker: UIDatePicker) {
      let parts = Calendar.current.dateComponents([.hour, .minute], from: picker.date)
      set(ClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0))
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
