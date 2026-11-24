@preconcurrency import FamilyControls
import Foundation
import Observation
import TollCore
import TollScreenTime

/// A block being made or changed: a draft until Save, which sends it through the app model. The engine
/// refuses what breaks a limit; the refusal is shown, nothing else checks it (docs/architecture.md).
/// A new block starts at its kind: the kind brings a name and hours (`BlockDraft`), and picking it
/// opens the apps picker, so adding one is a kind, the apps and Save (#89).
@MainActor
@Observable
final class BlockEditorModel {
  let app: AppModel
  let isNew: Bool
  var block: Block
  var place: Place?
  var selection: FamilyActivitySelection
  /// False on a new block until a kind is picked: the screen shows only the kinds.
  private(set) var kindPicked: Bool
  /// The title, as saved: it doesn't follow the name field while it's typed.
  let title: String
  private(set) var refusal: String?

  init(app: AppModel, editing id: BlockID?) {
    self.app = app
    if let id, let existing = app.draft(id) {
      isNew = false
      block = existing
      place = app.draftPlace(existing.place)
      kindPicked = true
      title = existing.isSleep ? Copy.Blocks.nightTitle : existing.name
    } else {
      isNew = true
      block = BlockDraft.new(.study, config: app.config)
      place = nil
      kindPicked = false
      title = Copy.Blocks.new
    }
    // A new block has no apps yet; `block` cannot be read before every property is set.
    selection = Blocklist.selection(from: id.flatMap { app.draft($0) }?.apps)
    #if DEBUG
      // Renders can't tap a kind; a scenario names the one it shows picked (docs/renders.md).
      if isNew, let kind = DemoScenario.current?.newBlockKind { _ = pick(kind) }
    #endif
  }

  var isSleep: Bool { block.isSleep }
  /// When the block being edited ends, if it is on: saving waits until then (B-3), and the editor
  /// says so.
  var activeUntil: Date? { isNew ? nil : app.state.runtime.active[block.id] }

  var activeNote: String? {
    guard let end = activeUntil.map({ Copy.time($0) }) else { return nil }
    return isSleep
      ? Copy.Blocks.nightActiveNote(until: end) : Copy.Blocks.activeNote(title, until: end)
  }

  /// With a place but no Always, the block runs on its hours wherever the user is (D37); the editor
  /// says so under Place (#49).
  var placeIgnored: String? {
    guard let place, app.state.location == .scheduleOnly,
      let window = block.schedule.windows.first
    else { return nil }
    if isSleep { return Copy.Blocks.nightPlaceIgnored(span: Copy.span(window)) }
    if block.onlyAtPlace { return Copy.Blocks.waitsForAlways(block.name, place: place.name) }
    return Copy.Blocks.placeIgnored(block.name, span: Copy.span(window))
  }

  /// Saving a block tied to a place without Always asks whether it runs anywhere or waits (#63).
  var asksAboutAlways: Bool { place != nil && !isSleep && app.state.location == .scheduleOnly }

  /// The question's words: the place and the hours.
  var alwaysQuestion: (place: String, body: String)? {
    guard let place, let window = block.schedule.windows.first else { return nil }
    return (
      place.name,
      Copy.Blocks.withoutAlwaysBody(block.name, place: place.name, span: Copy.span(window))
    )
  }

  /// "2 categories · 2 apps", counted, since iOS never gives the app the names (D41).
  var appsSummary: String {
    guard hasApps else { return Copy.Blocks.chooseAppsToSave }
    return Copy.Blocks.summary(
      categories: selection.categoryTokens.count, apps: Blocklist.items(selection))
  }

  var hasApps: Bool { !Blocklist.isEmpty(selection) }

  /// The name field, cut at the longest name the block screen holds (#62).
  var name: String {
    get { block.name }
    set { block.name = BlockDraft.name(newValue, config: app.config) }
  }

  /// The limits with this draft in place.
  func limits() -> BlockLimits {
    var draft = block
    draft.appCount = Blocklist.items(selection)
    draft.categoryCount = selection.categoryTokens.count
    return BlockLimits(state: app.state, draft: draft, config: app.config)
  }

  /// A change of hours that would make a ninth time window (D40): said under the hours, and Save
  /// stays off until it's undone.
  var windowsOver: Bool {
    let limits = limits()
    return limits.windowsUsed > limits.windowsMax
  }

  /// Picks a kind: its name and hours follow unless the user changed them (`BlockDraft.change`).
  /// Returns true when the apps picker should open: the first pick on a new block with no apps yet.
  func pick(_ kind: Block.Kind) -> Bool {
    block = BlockDraft.change(block, to: kind, config: app.config)
    kindPicked = true
    return isNew && !hasApps
  }

  /// The set-home flow saved home, or anywhere, itself: the draft follows it, so Save doesn't undo it.
  func homeChanged() {
    place = app.draftPlace(app.sleepDraft?.place)
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
    block = BlockDraft.finished(block)
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
    kindPicked && hasApps && block.schedule.isValid && limits().appsOver == 0 && !windowsOver
      && (isSleep || BlockDraft.isValidName(block.name, config: app.config))
  }

  private func refuse(_ error: CommandError) -> Bool {
    refusal = Copy.Blocks.refused(
      error, maxApps: app.config.blocks.maxApps, maxBlocks: app.config.blocks.max,
      maxName: app.config.blocks.maxNameLength)
    return false
  }
}
