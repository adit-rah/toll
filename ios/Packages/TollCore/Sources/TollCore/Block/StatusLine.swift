import Foundation

/// Status's one line of state (spec §7 Status), decided apart from the view so it can be tested.
public enum StatusLine: Equatable, Sendable {
  case blocked(until: Date)
  case away
  case starts(at: Date, windowOnly: Bool)
  case noWindow

  public init(state: SleepState, now: Date, calendar: Calendar) {
    guard let window = state.settings.window, window.isValid else {
      self = .noWindow
      return
    }
    if state.blockOn, let end = state.blockEndsAt, end > now {
      self = .blocked(until: end)
    } else if state.homeCheck == .location, state.presence?.isHome == false,
      window.contains(now, calendar: calendar)
    {
      self = .away
    } else {
      let start = window.nextStart(after: now, calendar: calendar) ?? now
      self = .starts(at: start, windowOnly: state.homeCheck == .windowOnly)
    }
  }

  public func text(in calendar: Calendar = .current) -> String {
    switch self {
    case .blocked(let end): Copy.Status.blocked(until: Copy.time(end, in: calendar))
    case .away: Copy.Status.away
    case .starts(let start, let windowOnly):
      Copy.Status.starts(at: Copy.time(start, in: calendar), windowOnly: windowOnly)
    case .noWindow: Copy.Status.noWindow
    }
  }
}
