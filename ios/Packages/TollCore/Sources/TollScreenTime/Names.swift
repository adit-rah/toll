#if os(iOS)
  @preconcurrency import DeviceActivity
  import Foundation
  @preconcurrency import ManagedSettings
  import TollCore

  extension ManagedSettingsStore.Name {
    /// The one store every block's shield lives in, so the door's exception applies to all of them.
    /// Computed because `Name` is not Sendable.
    public static var sleep: Self { Self("sleep") }
  }

  /// What a DeviceActivity name stands for. Names carry their window ("w.2230-0700"), so the monitor
  /// knows what woke it without reading the state first.
  public enum Activity: Equatable, Sendable {
    case window(TimeWindow)
    case sweep(TimeWindow)
    /// The daily wake at the week's turn (#127), "t.1201-1216".
    case turn(TimeWindow)
    case door
    /// Step 2's names and Toll's: stopped when they fire (decisions D28).
    case unknown

    public init(_ name: DeviceActivityName) {
      let raw = name.rawValue
      if raw == "door" {
        self = .door
        return
      }
      let parts = raw.split(separator: ".", maxSplits: 1)
      guard parts.count == 2, let window = Self.window(parts[1]) else {
        self = .unknown
        return
      }
      switch parts[0] {
      case "w": self = .window(window)
      case "s": self = .sweep(window)
      case "t": self = .turn(window)
      default: self = .unknown
      }
    }

    public var name: DeviceActivityName {
      switch self {
      case .window(let window): DeviceActivityName("w.\(Self.code(window))")
      case .sweep(let window): DeviceActivityName("s.\(Self.code(window))")
      case .turn(let window): DeviceActivityName("t.\(Self.code(window))")
      case .door: DeviceActivityName("door")
      case .unknown: DeviceActivityName("unknown")
      }
    }

    static func code(_ window: TimeWindow) -> String {
      func hhmm(_ time: ClockTime) -> String { String(format: "%02d%02d", time.hour, time.minute) }
      return "\(hhmm(window.start))-\(hhmm(window.end))"
    }

    static func window(_ code: Substring) -> TimeWindow? {
      let halves = code.split(separator: "-")
      guard halves.count == 2, let start = time(halves[0]), let end = time(halves[1]) else {
        return nil
      }
      return TimeWindow(start: start, end: end)
    }

    static func time(_ text: Substring) -> ClockTime? {
      guard text.count == 4, let value = Int(text), value / 100 < 24, value % 100 < 60 else {
        return nil
      }
      return ClockTime(hour: value / 100, minute: value % 100)
    }
  }
#endif
