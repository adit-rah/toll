import Foundation

/// Status's one line of state (spec §7 Status), decided apart from the view so it can be tested. Until
/// Home is redesigned it speaks for the Sleep block and for any block that is on.
public enum StatusLine: Equatable, Sendable {
  case blocked(until: Date)
  case away
  case starts(at: Date, scheduleOnly: Bool)
  case noWindow

  public init(state: DuskState, now: Date, calendar: Calendar) {
    guard let sleep = state.sleepBlock, sleep.schedule.isValid else {
      self = .noWindow
      return
    }
    let ends = state.runtime.active.values.filter { $0 > now }
    if let end = ends.max() {
      self = .blocked(until: end)
    } else if state.location == .places, let home = sleep.place,
      state.presence[home]?.isInside == false,
      sleep.schedule.occurrence(containing: now, calendar: calendar) != nil
    {
      self = .away
    } else {
      let start = sleep.schedule.nextStart(after: now, calendar: calendar) ?? now
      self = .starts(at: start, scheduleOnly: state.location == .scheduleOnly || sleep.place == nil)
    }
  }

  public func text(in calendar: Calendar = .current) -> String {
    switch self {
    case .blocked(let end): Copy.Status.blocked(until: Copy.time(end, in: calendar))
    case .away: Copy.Status.away
    case .starts(let start, let scheduleOnly):
      Copy.Status.starts(at: Copy.time(start, in: calendar), windowOnly: scheduleOnly)
    case .noWindow: Copy.Status.noWindow
    }
  }
}
