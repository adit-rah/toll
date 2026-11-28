import Foundation

extension Morning {
  /// Last night's sleep as Health measured it (#86, #88): "Asleep 11:20 pm – 6:55 am · 7 h 35 m",
  /// where it sat on the night's bar, and the folded row's "Asleep 7 h 35 m".
  public struct Asleep: Equatable, Sendable {
    public var line: String
    public var status: String
    public var spoken: String
    public var statusSpoken: String
    /// Onset to wake, as fractions of the lock's planned hours, clamped to them.
    public var span: Span
  }

  /// What the night log adds to last night: Health's sleep from the record's correction, and the
  /// one ask for Health the morning after the first night that locked (#86). `history` is the
  /// night log's nights; `first` is whether last night was the first the lock ran.
  mutating func read(history: [PastNight], health: Bool, first: Bool, calendar: Calendar) {
    let slept = history.last { $0.night == night && $0.slept != nil }?.slept
    if let slept, slept.wake > slept.onset {
      let length = max(1, ended.timeIntervalSince(started))
      func fraction(_ date: Date) -> Double {
        min(1, max(0, date.timeIntervalSince(started) / length))
      }
      let from = Copy.time(slept.onset, in: calendar)
      let to = Copy.time(slept.wake, in: calendar)
      let minutes = slept.minutes
      asleep = Asleep(
        line: Copy.Morning.asleep(from: from, to: to, length: Copy.length(minutes: minutes)),
        status: Copy.Morning.statusAsleep(Copy.length(minutes: minutes)),
        spoken: Copy.Morning.spokenAsleep(from: from, to: to, minutes: minutes),
        statusSpoken: Copy.Morning.spokenStatusAsleep(minutes: minutes),
        span: Span(start: fraction(slept.onset), end: fraction(slept.wake)))
    }
    guard first, outcome == .ran else { return }
    asksHealth = !health
    healthEmpty = health && asleep == nil
  }
}
