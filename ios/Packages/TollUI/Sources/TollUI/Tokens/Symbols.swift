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
  /// The buffer before sleep, when apps lock before the moon (D76): Tonight's gap cards and Ready.
  public static let beforeBed = TollSymbol("moon.haze")
  /// The buffer after waking, when apps stay locked after the sun (#144).
  public static let afterWake = TollSymbol("sun.haze")
  /// Apps open again, where the night's lock ends (#144).
  public static let open = TollSymbol("lock.open")
  /// Apple Health, where Dusk can read past sleep (#144).
  public static let health = TollSymbol("heart.text.square")
  /// Personal timing (D65, #171): the week's lock may start a little either way. Its offer, its
  /// switch in Settings › Sleep, and Tonight's line when this week's start isn't the person's own.
  public static let timing = TollSymbol("arrow.left.and.right")
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
  /// Off: the free nights ended or a block is switched off, so nothing blocks. Never a pause glyph:
  /// those are the pause's (D57, D70).
  public static let off = TollSymbol("power")
  /// Nothing can block (Screen Time off, a refusal).
  public static let broken = TollSymbol("exclamationmark.triangle")
  /// Working, but less than asked (location While Using).
  public static let degraded = TollSymbol("location.slash")
  /// A block waiting for Always location (#63).
  public static let waiting = TollSymbol("hourglass.bottomhalf.filled")
  /// Changes can't be saved until the app is updated: a build older than the state file it read
  /// (#140).
  public static let readOnly = TollSymbol("exclamationmark.arrow.triangle.2.circlepath")

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
  /// Sharing Your sky's picture, on a landmark morning only (D79), and the testing log's night
  /// records.
  public static let share = TollSymbol("square.and.arrow.up")

  // Settings' App and Help rows (#168): each leads with its tile, as "Is everything working?" does
  /// Dark, Light or Match iPhone.
  public static let appearance = TollSymbol("circle.lefthalf.filled")
  /// The free nights before the purchase, beside their segments.
  public static let freeNights = TollSymbol("gift")
  /// Restoring a purchase made on another phone or before a reinstall.
  public static let restore = TollSymbol("arrow.clockwise")
  /// How it works, Dusk's rules in a sheet.
  public static let howItWorks = TollSymbol("questionmark.circle")
  /// Writing to the founders.
  public static let contact = TollSymbol("envelope")
  /// The activity log, kept while Dusk is tested.
  public static let log = TollSymbol("list.bullet.rectangle")

  // Your sleep's measures (#87, #88)
  /// Asleep, as Health measured it: falling asleep, and last night's sleep on its card.
  public static let asleep = TollSymbol("zzz")
  /// How long the night's sleep lasted.
  public static let timeAsleep = TollSymbol("bed.double")
  /// How steady a time is from night to night.
  public static let steady = TollSymbol("metronome")
  /// Reaching for a locked app after the lock.
  public static let reach = TollSymbol("hand.tap")
  /// A change against the person's own first nights: the way this measure improves, the other
  /// way, or about the same. With `ok` for the first, never colour alone.
  public static let trendToward = TollSymbol("arrow.up.right")
  public static let trendAway = TollSymbol("arrow.down.right")
  public static let trendSame = TollSymbol("equal")
}

extension Image {
  /// A Dusk symbol; it survives the wordless render (design §5).
  public init(symbol: TollSymbol) {
    self.init(systemName: symbol.name)
  }
}

/// A glyph's size that grows with Dynamic Type, like the text it sits beside (#124): a fixed
/// point size stays small at AX5 while its words grow around it.
private struct ScaledGlyph: ViewModifier {
  @ScaledMetric private var size: CGFloat
  let weight: Font.Weight

  init(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) {
    _size = ScaledMetric(wrappedValue: size, relativeTo: style)
    self.weight = weight
  }

  func body(content: Content) -> some View {
    content.font(.system(size: size, weight: weight))
  }
}

extension View {
  /// Sizes a symbol at `size` points at the default text size, scaled with `style`.
  public func tollGlyph(
    _ size: CGFloat, weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .footnote
  ) -> some View {
    modifier(ScaledGlyph(size: size, weight: weight, relativeTo: style))
  }
}
