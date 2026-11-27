import Foundation

/// A block's row on Blocks: what it says, and the state its glyph shows (#72). Tonight shows none of
/// these (D68).
extension BlocksSnapshot {
  /// `blocking` is false with Screen Time off: nothing is on, whatever the schedule says (#45).
  static func row(
    _ block: Block, state: DuskState, now: Date, calendar: Calendar, blocking: Bool = true
  ) -> Row {
    if blocking, let end = state.runtime.active[block.id], state.trial.entitled,
      let held = heldFact(block, state: state, at: Copy.time(end, in: calendar))
    {
      return Row(
        id: block.id, name: block.name, kind: block.kind, detail: held.text, facts: [held],
        stateText: Copy.Home.onNow, state: .on)
    }
    var facts: [Fact] = []
    if let place = placeFact(block, state: state) { facts.append(place) }
    if let window = block.schedule.windows.first {
      facts.append(Fact(.hours, Copy.span(window, in: calendar, short: true)))
    }
    if let days = Self.days(block.schedule) {
      facts.append(Fact(days == Copy.Home.weekendsDiffer ? .weekendsDiffer : .days, days))
    }
    let stateText: String
    let rowState: Row.State
    if Engine.waitsForAlways(block, state) {
      (stateText, rowState) = (Copy.Blocks.waiting, .waiting)
    } else if !block.isOn || !state.trial.entitled || !blocking {
      (stateText, rowState) = (Copy.Home.off, .off)
    } else if state.runtime.active[block.id] != nil {
      (stateText, rowState) = (Copy.Home.onNow, .on)
    } else if let next = block.schedule.nextStart(after: now, calendar: calendar) {
      // "Tonight" and "Today" only for today; a night starting after midnight still counts as
      // tonight. Anything later is its weekday.
      let today = calendar.isDate(next, inSameDayAs: now)
      let afterMidnight =
        block.isSleep
        && calendar.isDate(next, inSameDayAs: now.addingTimeInterval(86_400))
        && calendar.component(.hour, from: next) < 6
      let day =
        today || afterMidnight
        ? (block.isSleep ? Copy.Home.tonight : Copy.Home.today)
        : Copy.shortWeekday(next, in: calendar)
      // Another block says when it starts too: "Wed" alone didn't say when (the audit). The night
      // keeps "Tonight"; its picture has the time.
      stateText = block.isSleep ? day : "\(day) \(Copy.time(next, in: calendar, short: true))"
      rowState = .later
    } else {
      (stateText, rowState) = ("", .unscheduled)
    }
    return Row(
      id: block.id, name: block.name, kind: block.kind,
      detail: line(facts), facts: facts, stateText: stateText, state: rowState)
  }

  /// "Weekdays", "Weekends", or nothing for every day; one rule's days stand for the block.
  static func days(_ schedule: WeeklySchedule) -> String? {
    let all = schedule.rules.reduce(into: Set<Weekday>()) { $0.formUnion($1.days) }
    if all == Weekday.all { return schedule.rules.count > 1 ? Copy.Home.weekendsDiffer : nil }
    if all == Weekday.weekdays { return Copy.Home.weekdays }
    if all == [.saturday, .sunday] { return Copy.Home.weekends }
    return all.sorted().map { Copy.Home.shortDay($0) }.joined(separator: " ")
  }
}
