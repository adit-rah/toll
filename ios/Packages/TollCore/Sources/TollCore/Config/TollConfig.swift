import Foundation

/// Every tunable (spec §14, insights §9). Defaults here; `GET /config` may override any key.
public struct TollConfig: Codable, Sendable, Equatable {
  public struct Gate: Codable, Sendable, Equatable {
    public init() {}
    public var freePassesPerDay = 2
    public var waits = [3, 5, 8]
    public var dayResetHour = 4
    public var sessionMinutes = [5, 10, 15]
    public var resumeWindowSeconds = 120
    public var clockSkewToleranceSeconds = 60
  }

  public struct Status: Codable, Sendable, Equatable {
    public init() {}
    /// Upper bounds of level 1 and level 2: 0–2, 3–4, 5+.
    public var levelBounds = [2, 4]
    public var personalise = true
  }

  public struct Network: Codable, Sendable, Equatable {
    public init() {}
    public var pinHours = 24
    public var schoolMinMembers = 20
    public var silenceMissedCheckins = 2
    public var tags = Tag.allCases.map(\.rawValue)
  }

  public struct Identity: Codable, Sendable, Equatable {
    public init() {}
    public var handleCooldownDays = 30
    public var photoMaxPx = 512
  }

  public struct Notify: Codable, Sendable, Equatable {
    public init() {}
    public var hour = 10
  }

  public struct Blocks: Codable, Sendable, Equatable {
    public init() {}
    public var maxTokens = 40
    public var max = 8
    public var presets = SchedulePresets()
  }

  public struct Sync: Codable, Sendable, Equatable {
    public init() {}
    public var flushIntervalSeconds = 300
  }

  public struct Insights: Codable, Sendable, Equatable {
    public init() {}
    public var lateStart = 23
    public var minN = 5
    public var friendsMinN = 3
    public var schoolBinMin = 5
    public var examMarkMin = 10
    public var maxBins = 8
  }

  public struct Share: Codable, Sendable, Equatable {
    public init() {}
    public var formats = ["story", "square"]
  }

  public var gate = Gate()
  public var status = Status()
  public var network = Network()
  public var identity = Identity()
  public var notify = Notify()
  public var blocks = Blocks()
  public var sync = Sync()
  public var insights = Insights()
  public var share = Share()

  public init() {}

  public static let defaults = TollConfig()

  /// Decodes a remote document over the defaults, so a missing or unknown key never breaks the app.
  public static func merging(remoteJSON data: Data) -> TollConfig {
    guard
      let remote = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let base = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(defaults))
        as? [String: Any]
    else { return defaults }
    let merged = deepMerge(base, remote)
    guard let mergedData = try? JSONSerialization.data(withJSONObject: merged) else {
      return defaults
    }
    return (try? JSONDecoder().decode(TollConfig.self, from: mergedData)) ?? defaults
  }

  private static func deepMerge(_ base: [String: Any], _ patch: [String: Any]) -> [String: Any] {
    var out = base
    for (key, value) in patch {
      if let patchDict = value as? [String: Any], let baseDict = out[key] as? [String: Any] {
        out[key] = deepMerge(baseDict, patchDict)
      } else if out[key] != nil {
        out[key] = value
      }
    }
    return out
  }
}

/// The When chips' fixed windows (spec §14 `blocks.presets`).
public struct SchedulePresets: Codable, Sendable, Equatable {
  public init() {}
  public var nights = Window(start: ClockTime(hour: 23), end: ClockTime(hour: 7), days: Weekday.all)
  public var weekdays = Window(
    start: ClockTime(hour: 9), end: ClockTime(hour: 17), days: Weekday.workweek)

  public struct Window: Codable, Sendable, Equatable {
    public var start: ClockTime
    public var end: ClockTime
    public var days: Set<Weekday>

    public init(start: ClockTime, end: ClockTime, days: Set<Weekday>) {
      self.start = start
      self.end = end
      self.days = days
    }
  }
}
