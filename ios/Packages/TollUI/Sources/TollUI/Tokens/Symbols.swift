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
  /// The night's end, opposite the moon at its start (D68: moon start – end sun).
  public static let sun = TollSymbol("sun.max")
  /// A "Never mind" tap: "You chose sleep 3 times" (#103).
  public static let phoneDown = TollSymbol("iphone.slash")
  /// A personal best, against the person's own past (D65).
  public static let best = TollSymbol("arrow.up.to.line")
  /// The gap before bed, when apps lock before the moon (D76): Tonight's gap cards and Ready.
  public static let beforeBed = TollSymbol("moon.haze")
  /// Before bed's helpers in the gap (D80): tomorrow's list on paper, the breathing tone, the word
  /// game with eyes closed. The capsule that opens them is the gap's own `beforeBed`.
  public static let list = TollSymbol("pencil")
  public static let breathe = TollSymbol("wind")
  public static let words = TollSymbol("eye.half.closed")
  /// The breathing tone playing, and stopping it.
  public static let tone = TollSymbol("speaker.wave.2")
  public static let stopTone = TollSymbol("speaker.slash")
  public static func helper(_ helper: Helper) -> TollSymbol {
    switch helper {
    case .list: list
    case .breathe: breathe
    case .words: words
    }
  }
  /// The heads-up before the night, Dusk's one notification (D68).
  public static let headsUp = TollSymbol("bell")
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
  /// Off: the free week ended or a block is switched off, so nothing blocks. Never a pause glyph:
  /// those are the pause's (D57, D70).
  public static let off = TollSymbol("power")
  /// Nothing can block (Screen Time off, a refusal).
  public static let broken = TollSymbol("exclamationmark.triangle")
  /// Working, but less than asked (location While Using).
  public static let degraded = TollSymbol("location.slash")
  /// A block waiting for Always location (#63).
  public static let waiting = TollSymbol("hourglass.bottomhalf.filled")

  // The pause (D67); the code keeps the spec's door and unlock
  /// A pause: on its button, its sheet and Home's capsule.
  public static let unlock = TollSymbol("pause")
  public static let wait = TollSymbol("timer")
  /// Lock again in time and keep the pause (D-4).
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
  /// Last night's folded row on Tonight opens upward, since it sits above the strip: the folded
  /// row points up, the open card's header down, toward the row it folds back to.
  public static let unfold = TollSymbol("chevron.up")
  public static let fold = TollSymbol("chevron.down")
  /// Sharing Your sky's picture, on a landmark morning only (D79).
  public static let share = TollSymbol("square.and.arrow.up")
}

extension Image {
  /// A Dusk symbol; it survives the wordless render (design §5).
  public init(symbol: TollSymbol) {
    self.init(systemName: symbol.name)
  }
}
