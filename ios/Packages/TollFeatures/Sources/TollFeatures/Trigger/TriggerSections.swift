@preconcurrency import FamilyControls
import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// Wake time sets the start (spec §7 setup 2); the start can then be moved on its own.
struct WindowSection: View {
  let model: AppModel
  @State private var wake = Date()
  @State private var start = Date()

  var body: some View {
    Section(Copy.Trigger.window) {
      DatePicker(Copy.Trigger.wake, selection: $wake, displayedComponents: .hourAndMinute)
        .onChange(of: wake) { _, newValue in
          let window = SleepWindow(wake: clock(newValue), leadHours: model.config.window.leadHours)
          start = date(window.start)
        }
      DatePicker(Copy.Trigger.start, selection: $start, displayedComponents: .hourAndMinute)
      if let window = model.state.settings.window {
        Text(Copy.window(window)).tollText(.caption)
      }
      Button(Copy.Trigger.save) {
        var edit = model.state.pending ?? model.state.settings
        edit.window = SleepWindow(start: clock(start), end: clock(wake))
        model.submit(edit)
      }
    }
    .onAppear {
      let window =
        model.state.settings.window
        ?? SleepWindow(wake: ClockTime(hour: 7), leadHours: model.config.window.leadHours)
      wake = date(window.end)
      start = date(window.start)
    }
  }

  private func clock(_ date: Date) -> ClockTime {
    let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
    return ClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
  }

  private func date(_ clock: ClockTime) -> Date {
    Calendar.current.date(bySettingHour: clock.hour, minute: clock.minute, second: 0, of: Date())
      ?? Date()
  }
}

struct HomeSection: View {
  let model: AppModel
  @State private var locating = false
  @State private var failed = false

  var body: some View {
    Section(Copy.Trigger.homeSection) {
      if let home = model.state.settings.home {
        Text(Copy.Trigger.radius(Int(home.radiusMeters)))
      } else {
        Text(Copy.Trigger.noHome)
      }
      Button(locating ? Copy.Trigger.locating : Copy.Trigger.setHomeHere) {
        Task { await setHere() }
      }
      .disabled(locating)
      if failed { Text(Copy.Trigger.noFix).tollText(.caption) }
    }
  }

  private func setHere() async {
    locating = true
    defer { locating = false }
    guard let point = await model.locationAccess.here(radiusMeters: model.config.home.radiusMeters)
    else {
      failed = true
      return
    }
    failed = false
    var edit = model.state.pending ?? model.state.settings
    edit.home = point
    model.submit(edit)
  }
}

struct KeepOpenSection: View {
  let model: AppModel
  @State private var picking = false
  @State private var selection = FamilyActivitySelection()

  var body: some View {
    Section(Copy.Trigger.keepOpen) {
      Text(
        Copy.Trigger.kept(
          apps: selection.applicationTokens.count, sites: selection.webDomainTokens.count,
          categories: selection.categoryTokens.count))
      Button(Copy.Trigger.choose) { picking = true }
    }
    .familyActivityPicker(isPresented: $picking, selection: $selection)
    .onAppear {
      selection = KeepOpen.selection(
        from: model.state.pending?.keepOpen ?? model.state.settings.keepOpen)
    }
    .onChange(of: picking) { _, isOpen in
      guard !isOpen else { return }
      var edit = model.state.pending ?? model.state.settings
      edit.keepOpen = KeepOpen.encode(selection)
      model.submit(edit)
    }
  }
}
