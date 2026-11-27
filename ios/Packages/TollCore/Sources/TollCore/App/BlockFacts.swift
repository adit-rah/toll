import Foundation

extension BlocksSnapshot {
  /// One fact on a block's line, with what its glyph shows, so the line reads without its words
  /// (#78, #110): a pin and a clock say where and when before "Library" and "9 am – 5 pm" do.
  public struct Fact: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
      case apps, home, place, anywhere, waiting, hours, weekendsDiffer
      /// The days after the hours ("Weekdays"): the hours' glyph covers them.
      case days
      /// A delete or an edit held until the block ends (B-3).
      case deleting, changing
    }

    public var kind: Kind
    public var text: String

    public init(_ kind: Kind, _ text: String) {
      self.kind = kind
      self.text = text
    }
  }

  /// Where a block runs, as it really runs (`placeText`), with the glyph for it: a house at Home,
  /// a pin elsewhere, a globe while location isn't usable, the hourglass while it waits for Always.
  static func placeFact(_ block: Block, state: DuskState) -> Fact? {
    guard let text = placeText(block, state: state) else { return nil }
    if Engine.waitsForAlways(block, state) { return Fact(.waiting, text) }
    if state.location == .scheduleOnly { return Fact(.anywhere, text) }
    return Fact(state.isHome(block.place) ? .home : .place, text)
  }

  /// A delete or edit held until the block ends, as the line's one fact.
  static func heldFact(_ block: Block, state: DuskState, at time: String) -> Fact? {
    guard let text = held(block, state: state, at: time) else { return nil }
    if case .delete = state.pending[block.id] { return Fact(.deleting, text) }
    return Fact(.changing, text)
  }

  /// The words VoiceOver and the tests read: the facts in order, as one line.
  static func line(_ facts: [Fact]) -> String {
    facts.map(\.text).joined(separator: Copy.middleDot)
  }
}
