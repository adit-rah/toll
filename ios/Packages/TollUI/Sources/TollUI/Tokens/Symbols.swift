import SwiftUI
import TollCore

/// One SF Symbol per concept, everywhere (design §2.6, #72): the wordless test reads a screen by its
/// symbols, so a symbol never means two things and a concept never has two symbols. Features name a
/// concept here; none types a symbol string.
public struct TollSymbol: Hashable, Sendable {
  public let name: String

  init(_ name: String) {
    self.name = name
  }

  // Blocks and nights
  public static let sleep = TollSymbol("moon")
  /// A night's end, drawn after its time as the moon is before its start (D68).
  public static let morning = TollSymbol("sun.max")
  public static func block(_ kind: Block.Kind) -> TollSymbol {
    switch kind {
    case .sleep: sleep
    case .study: TollSymbol("book")
    case .work: TollSymbol("briefcase")
    case .gym: TollSymbol("bolt")
    case .other: TollSymbol("ellipsis")
    }
  }

  // State: the glyph before a state's eyebrow and on its rows
  public static let blocked = TollSymbol("lock")
  public static let later = TollSymbol("clock")
  public static let away = TollSymbol("figure.walk")
  public static let paused = TollSymbol("pause.circle")
  /// Nothing can block (Screen Time off, a refusal).
  public static let broken = TollSymbol("exclamationmark.triangle")
  /// Working, but less than asked (location While Using).
  public static let degraded = TollSymbol("location.slash")
  /// A block waiting for Always location (#63).
  public static let waiting = TollSymbol("hourglass.bottomhalf.filled")

  // The door
  public static let unlock = TollSymbol("lock.open")
  public static let wait = TollSymbol("timer")
  /// Lock again in time and keep the unlock (D-4).
  public static let keep = TollSymbol("arrow.uturn.backward")

  // What a block holds and where
  public static let apps = TollSymbol("square.grid.2x2")
  /// A block's hours, a time of day.
  public static let hours = TollSymbol("clock")
  public static let home = TollSymbol("house")
  public static let place = TollSymbol("mappin")
  public static let anywhere = TollSymbol("globe")
  /// The current position and the Location permission, nothing else.
  public static let location = TollSymbol("location")
  public static let precise = TollSymbol("scope")
  public static let screenTime = TollSymbol("hourglass")
  public static let weekends = TollSymbol("calendar")
  public static let wake = TollSymbol("alarm")

  // Outcomes and actions
  public static let done = TollSymbol("checkmark")
  public static let purchased = TollSymbol("checkmark.seal")
  public static let failed = TollSymbol("xmark")
  public static let askToBuy = TollSymbol("person.badge.clock")
  public static let notFound = TollSymbol("magnifyingglass")
  /// Anything that leaves for iOS Settings.
  public static let openSettings = TollSymbol("arrow.up.forward.app")
  public static let privacy = TollSymbol("hand.raised")
  public static let insights = TollSymbol("chart.bar")
  /// The Blocks tab: every block.
  public static let blocks = TollSymbol("rectangle.stack")
  public static let settings = TollSymbol("gearshape")
  public static let add = TollSymbol("plus")
  public static let delete = TollSymbol("trash")
  public static let forward = TollSymbol("chevron.right")
}

extension Image {
  /// A Dusk symbol; it survives the wordless render (design §5).
  public init(symbol: TollSymbol) {
    self.init(systemName: symbol.name)
  }
}
