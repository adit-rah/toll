import Foundation

/// What the block screen says (spec §7, D32), for the block that names the app. A snapshot: decided
/// here, tested, and only laid out by the extension.
public struct ShieldText: Equatable, Sendable {
  public var title: String
  /// Why it's blocked, then the unlocks: the supply shows wherever the door is offered (D-5).
  public var subtitle: String
  /// "Unlock in Dusk", dropped at 0: the door isn't offered then (D-5, #47).
  public var offersDoor: Bool

  public init(
    state: DuskState, block: Block?, calendar: Calendar = .current, config: TollConfig = .defaults
  ) {
    let end = block.flatMap { state.runtime.active[$0.id] }
    let time = end.map { Copy.time($0, in: calendar) }
    let left = state.unlocks.left(config)
    offersDoor = left > 0
    let supply =
      left > 0
      ? Copy.Shield.unlocks(left, of: config.unlocks.max)
      : Copy.Door.noneLeft(
        nights: state.unlocks.nightsToRefill(config) ?? config.unlocks.refillNights)
    guard let block, !block.isSleep else {
      title = time.map(Copy.Shield.title(until:)) ?? Copy.Shield.title
      subtitle = "\(Copy.Shield.subtitle) \(supply)"
      return
    }
    title = time.map { Copy.Shield.blockTitle(block.name, until: $0) } ?? block.name
    subtitle = "\(Copy.Shield.blockOn(block.name)) \(supply)"
  }
}
