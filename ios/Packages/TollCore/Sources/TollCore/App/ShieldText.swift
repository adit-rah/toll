import Foundation

/// What the block screen says (spec §7, D32), for the block that names the app. A snapshot: decided
/// here, tested, and only laid out by the extension.
public struct ShieldText: Equatable, Sendable {
  public var title: String
  public var subtitle: String

  public init(state: DuskState, block: Block?, calendar: Calendar = .current) {
    let end = block.flatMap { state.runtime.active[$0.id] }
    let time = end.map { Copy.time($0, in: calendar) }
    guard let block, !block.isSleep else {
      title = time.map(Copy.Shield.title(until:)) ?? Copy.Shield.title
      let atHome = state.location == .places && state.sleepBlock?.place != nil
      subtitle = atHome ? Copy.Shield.subtitle : Copy.Shield.subtitleWindowOnly
      return
    }
    title = time.map { Copy.Shield.blockTitle(block.name, until: $0) } ?? block.name
    if state.location == .places, let place = state.place(block.place) {
      subtitle = Copy.Shield.atPlace(place.name)
    } else {
      subtitle = Copy.Shield.blockOn(block.name)
    }
  }
}
