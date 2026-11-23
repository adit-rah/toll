import Foundation

/// A block other than the night, as the editor starts it and changes its kind (#89, #62). Adding one
/// is a kind, the apps and Save: the kind brings a name and hours, and the place stays Anywhere until
/// the user picks one.
public enum BlockDraft {
  /// The kinds a user can add, in the order the editor shows them. The night is set up, never added.
  public static let kinds: [Block.Kind] = [.study, .work, .gym, .other]

  /// A new block of `kind`: its name, its default hours, no apps and no place.
  public static func new(_ kind: Block.Kind, config: TollConfig = .defaults) -> Block {
    Block(
      name: Copy.Blocks.kindName(kind), kind: kind, place: nil,
      schedule: schedule(for: kind, config: config), apps: nil)
  }

  /// The hours a block of `kind` starts with (`TollConfig.Blocks`).
  public static func schedule(for kind: Block.Kind, config: TollConfig = .defaults)
    -> WeeklySchedule
  {
    let hours: TollConfig.Hours
    switch kind {
    case .study: hours = config.blocks.study
    case .work: hours = config.blocks.work
    case .gym: hours = config.blocks.gym
    case .other, .sleep: hours = config.blocks.other
    }
    return WeeklySchedule(rules: [
      .init(days: hours.days, window: TimeWindow(start: hours.start, end: hours.end))
    ])
  }

  /// The block as another kind. What the user typed or chose stays theirs: the name follows the kind
  /// only while it is still the old kind's name, and the hours only while they are still the old
  /// kind's defaults. The night never changes kind.
  public static func change(_ block: Block, to kind: Block.Kind, config: TollConfig = .defaults)
    -> Block
  {
    guard !block.isSleep, kind != .sleep, kind != block.kind else { return block }
    var changed = block
    if block.name == Copy.Blocks.kindName(block.kind) { changed.name = Copy.Blocks.kindName(kind) }
    if block.schedule == schedule(for: block.kind, config: config) {
      changed.schedule = schedule(for: kind, config: config)
    }
    changed.kind = kind
    return changed
  }

  /// The name as typed, cut at `maxNameLength` characters, so typing never makes Save refuse.
  public static func name(_ typed: String, config: TollConfig = .defaults) -> String {
    String(typed.prefix(config.blocks.maxNameLength))
  }

  /// The block as saved: spaces typed at either end of the name dropped.
  public static func finished(_ block: Block) -> Block {
    var finished = block
    finished.name = block.name.trimmingCharacters(in: .whitespacesAndNewlines)
    return finished
  }

  /// Whether a name can be saved: something besides spaces, and short enough for the block screen.
  public static func isValidName(_ name: String, config: TollConfig = .defaults) -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return !trimmed.isEmpty && name.count <= config.blocks.maxNameLength
  }
}

extension DuskState {
  /// Home is wherever the night's block is, so the editor's place row draws a house there and a pin
  /// anywhere else (#78).
  public func isHome(_ place: PlaceID?) -> Bool {
    place != nil && sleepBlock?.place == place
  }
}
