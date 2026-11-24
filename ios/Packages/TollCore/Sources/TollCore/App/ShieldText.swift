import Foundation

/// What the block screen says (spec §7, D32), for the block that names the app. A snapshot: decided
/// here, tested, and only laid out by the extension.
public struct ShieldText: Equatable, Sendable {
  public var title: String
  /// Why it's blocked, then the pauses left this week: the supply shows wherever a pause is offered.
  public var subtitle: String
  /// "Open Dusk to pause", dropped at 0: no pause is offered then (#47, D67).
  public var offersDoor: Bool
  /// What the block screen's picture draws (#75): the block's symbol, and the pauses as dots.
  public var kind: Block.Kind
  public var unlocksLeft: Int
  public var unlocksMax: Int

  public init(
    state: DuskState, block: Block?, now: Date, calendar: Calendar = .current,
    config: TollConfig = .defaults
  ) {
    let end = block.flatMap { state.runtime.active[$0.id] }
    let time = end.map { Copy.time($0, in: calendar) }
    let left = state.unlocks.left(config, now: now, calendar: calendar)
    offersDoor = left > 0
    kind = block?.kind ?? .sleep
    unlocksLeft = left
    unlocksMax = config.unlocks.max
    let refill = UnlockSupply.refill(after: now, calendar: calendar, config: config)
    let supply =
      left > 0
      ? Copy.Shield.pauses(left, of: config.unlocks.max)
      : Copy.Shield.noneLeft(back: Copy.Door.refillDay(refill, now: now, in: calendar))
    title = time.map(Copy.Shield.title(until:)) ?? Copy.Shield.title
    guard let block, !block.isSleep else {
      subtitle = "\(Copy.Shield.subtitle) \(supply)"
      return
    }
    subtitle = "\(Copy.Shield.blockOn(block.name)) \(supply)"
  }
}
