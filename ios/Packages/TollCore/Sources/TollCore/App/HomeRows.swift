import Foundation

/// Home's block rows: what each says, and the state its glyph shows (#72).
extension HomeSnapshot {
  /// `blocking` is false with Screen Time off: nothing is on, whatever the schedule says (#45).
  static func row(
    _ block: Block, state: DuskState, now: Date, calendar: Calendar, blocking: Bool = true
  ) -> BlockRow {
    if blocking, let end = state.runtime.active[block.id], state.trial.entitled,
      let held = BlocksSnapshot.held(block, state: state, at: Copy.time(end, in: calendar))
    {
      return BlockRow(
        id: block.id, name: block.name, kind: block.kind, detail: held,
        trailing: Copy.Home.onNow, trailingIsAccent: true, state: .on)
    }
    var parts: [String] = []
    if let place = BlocksSnapshot.placeText(block, state: state) { parts.append(place) }
    if let window = block.schedule.windows.first {
      parts.append(Copy.span(window, in: calendar, short: true))
    }
    if let days = Self.days(block.schedule) { parts.append(days) }
    let trailing: (String, Bool)
    let rowState: BlockRow.State
    if Engine.waitsForAlways(block, state) {
      trailing = (Copy.Blocks.waiting, false)
      rowState = .waiting
    } else if !block.isOn || !state.trial.entitled || !blocking {
      trailing = (block.isOn ? Copy.Home.paused : Copy.Home.off, false)
      rowState = block.isOn ? .paused : .off
    } else if state.runtime.active[block.id] != nil {
      trailing = (Copy.Home.onNow, true)
      rowState = .on
    } else if let next = block.schedule.nextStart(after: now, calendar: calendar) {
      // "Tonight" and "Today" only for today; a Sleep night starting after midnight still counts as
      // tonight. Anything later is its weekday.
      let today = calendar.isDate(next, inSameDayAs: now)
      let afterMidnight =
        block.isSleep
        && calendar.isDate(next, inSameDayAs: now.addingTimeInterval(86_400))
        && calendar.component(.hour, from: next) < 6
      trailing =
        today || afterMidnight
        ? (block.isSleep ? Copy.Home.tonight : Copy.Home.today, true)
        : (
          next.formatted(
            Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone).weekday(.abbreviated)),
          false
        )
      rowState = .later
    } else {
      trailing = ("", false)
      rowState = .unscheduled
    }
    return BlockRow(
      id: block.id, name: block.name, kind: block.kind,
      detail: parts.joined(separator: Copy.middleDot),
      trailing: trailing.0, trailingIsAccent: trailing.1, state: rowState)
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
