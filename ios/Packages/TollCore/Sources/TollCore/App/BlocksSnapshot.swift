import Foundation

/// The Blocks tab (D63, quieter by D68 and #89): the night leads, drawn as moon start – end sun and
/// never as a block called "Sleep"; the other blocks follow as compact rows, each with its state as a
/// glyph; the limits sit under them.
public struct BlocksSnapshot: Equatable, Sendable {
  /// The night's hours as setup drew them, with its state and what it holds.
  public struct Night: Equatable, Sendable {
    public var id: BlockID
    /// Tonight's night, or the next one; nil only for a schedule with no nights.
    public var picture: NightPicture?
    public var state: Row.State
    /// "On now", "Tonight", "Off"; empty when there's nothing to say.
    public var stateText: String
    /// "4 apps · Home · Weekends differ", or a change held until the night ends (B-3).
    public var detail: String
    /// The same, fact by fact, each with its glyph (#110).
    public var facts: [Fact]
  }

  /// One block other than the night.
  public struct Row: Equatable, Sendable, Identifiable {
    /// What the row's glyph says (#72, rule 2); `stateText` says the same in words.
    public enum State: Equatable, Sendable {
      case on, later, off, waiting, unscheduled
    }

    public var id: BlockID
    public var name: String
    public var kind: Block.Kind
    /// "Library · 9 am – 5 pm · Weekdays", or a change held until it ends.
    public var detail: String
    /// The same, fact by fact, each with its glyph (#110).
    public var facts: [Fact]
    /// "On now", "Today", "Mon", "Waiting".
    public var stateText: String
    public var state: State
  }

  public var night: Night?
  public var others: [Row]
  /// More other blocks than `blocks.foldAbove` fold into one row (#110); nil while they fit.
  public var group: Group?
  public var limits: BlockLimits

  /// `screenTime` is false when Screen Time is off for Dusk: nothing is on then, whatever the
  /// schedule says (#45).
  public init(
    state: DuskState, now: Date, calendar: Calendar, config: TollConfig = .defaults,
    screenTime: Bool = true
  ) {
    let blocking = screenTime || state.setupFinishedAt == nil
    night = state.sleepBlock.map {
      Self.night($0, state: state, now: now, calendar: calendar, blocking: blocking)
    }
    others = state.blocks.filter { !$0.isSleep }.map {
      Self.row($0, state: state, now: now, calendar: calendar, blocking: blocking)
    }
    limits = BlockLimits(state: state, config: config)
    group = Self.group(others, state: state, calendar: calendar, config: config)
  }

  static func night(
    _ block: Block, state: DuskState, now: Date, calendar: Calendar, blocking: Bool
  ) -> Night {
    let row = Self.row(block, state: state, now: now, calendar: calendar, blocking: blocking)
    var facts = [
      Fact(.apps, Copy.Blocks.summary(categories: block.categoryCount, apps: block.appCount)),
      placeFact(block, state: state) ?? Fact(.anywhere, Copy.Blocks.anywhere),
    ]
    if block.schedule.rules.count > 1 {
      facts.append(Fact(.weekendsDiffer, Copy.Home.weekendsDiffer))
    }
    if let held = state.runtime.active[block.id].flatMap({
      Self.heldFact(block, state: state, at: Copy.time($0, in: calendar))
    }) {
      facts = [held]
    }
    // The strip is drawn as Tonight draws it: solid while on, dashed when nothing will block.
    var picture = NightPicture(block.schedule, now: now, calendar: calendar)
    switch row.state {
    case .on: picture?.timeline.phase = .on
    case .off: picture?.timeline.phase = .off
    case .later, .waiting, .unscheduled: break
    }
    return Night(
      id: block.id, picture: picture,
      state: row.state, stateText: row.stateText, detail: line(facts), facts: facts)
  }

  /// Where a block runs as it really runs: its place, or "Anywhere" while location isn't usable
  /// (D37), since then it blocks wherever the user is (#49). Nil for a block with no place.
  static func placeText(_ block: Block, state: DuskState) -> String? {
    guard let name = state.place(block.place)?.name else { return nil }
    if Engine.waitsForAlways(block, state) { return Copy.Blocks.needsAlways }
    return state.location == .scheduleOnly ? Copy.Blocks.anywhere : name
  }

  /// A delete or edit held until the block ends (B-3), said on its row so it doesn't look ignored.
  static func held(_ block: Block, state: DuskState, at time: String) -> String? {
    switch state.pending[block.id] {
    case .delete: Copy.Blocks.deletedAt(time)
    case .save: Copy.Blocks.changesAt(time)
    case nil: nil
    }
  }
}
