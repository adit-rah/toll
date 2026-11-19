@preconcurrency import FamilyControls
import Foundation
import Observation
import TollCore
import TollScreenTime

/// A block being made or changed: a draft until Save, which sends it through the app model. The engine
/// refuses what breaks a limit; the refusal is shown, nothing else checks it (docs/architecture.md).
@MainActor
@Observable
final class BlockEditorModel {
  let app: AppModel
  let isNew: Bool
  var block: Block
  var place: Place?
  var selection: FamilyActivitySelection
  private(set) var refusal: String?

  init(app: AppModel, editing id: BlockID?) {
    self.app = app
    if let id, let existing = app.draft(id) {
      isNew = false
      block = existing
      place = app.draftPlace(existing.place)
    } else {
      isNew = true
      block = Block(
        name: Copy.Blocks.kindName(.study), kind: .study, place: nil,
        schedule: WeeklySchedule(rules: [
          .init(
            days: Weekday.weekdays,
            window: TimeWindow(start: ClockTime(hour: 9), end: ClockTime(hour: 17)))
        ]), apps: nil)
      place = nil
    }
    // A new block has no apps yet; `block` cannot be read before every property is set.
    selection = Blocklist.selection(from: id.flatMap { app.draft($0) }?.apps)
  }

  var isSleep: Bool { block.isSleep }
  /// Saving an active block waits until it ends (B-3); the editor says so.
  var isActive: Bool { app.state.runtime.active[block.id] != nil }
  var kinds: [Block.Kind] { [.study, .work, .gym, .other] }

  func choose(_ kind: Block.Kind) {
    if block.name == Copy.Blocks.kindName(block.kind) { block.name = Copy.Blocks.kindName(kind) }
    block.kind = kind
  }

  func setRule(_ index: Int, _ rule: WeeklySchedule.Rule) {
    guard block.schedule.rules.indices.contains(index) else { return }
    block.schedule.rules[index] = rule
  }

  /// Returns true when saved (or held until the block ends).
  func save() -> Bool {
    if let place {
      if let refused = app.save(place) { return refuse(refused) }
    }
    block.place = place?.id
    block.apps = Blocklist.encode(selection)
    if let refused = app.save(block) { return refuse(refused) }
    return true
  }

  func delete() -> Bool {
    if let refused = app.delete(block.id) { return refuse(refused) }
    return true
  }

  var canSave: Bool {
    !Blocklist.isEmpty(selection) && block.schedule.isValid && !block.name.isEmpty
  }

  private func refuse(_ error: CommandError) -> Bool {
    refusal = Copy.Blocks.refused(
      error, maxApps: app.config.blocks.maxApps, maxBlocks: app.config.blocks.max)
    return false
  }
}
