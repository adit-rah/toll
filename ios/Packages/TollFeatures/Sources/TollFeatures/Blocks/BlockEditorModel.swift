@preconcurrency import FamilyControls
import Foundation
import Observation
import TollCore
import TollData
import TollScreenTime

/// One editor for setup's "Block these" and for New block / edit (flows §5, §14). The picker opens on
/// arrival; apps are listed with their friends-facing tag; When chips; optional name; Done.
@MainActor
@Observable
public final class BlockEditorModel {
  public enum Mode: Equatable {
    case setup(returning: Bool)
    case new
    case edit(BlockRef)
  }

  let app: AppModel
  public let mode: Mode
  public var selection = FamilyActivitySelection() {
    didSet { Task { await selectionChanged() } }
  }
  public var schedule: Schedule = .always
  public var name = ""
  public var pickerPresented = false
  public var customSheetPresented = false
  public private(set) var refs: [AppRef] = []
  public private(set) var kinds: [AppRef: TokenKind] = [:]
  public private(set) var tags: [AppRef: Tag] = [:]
  public private(set) var finished: [StoredBlock] = []
  public private(set) var otherTokens = 0
  public private(set) var isSaving = false
  private var original: StoredBlock?

  public init(app: AppModel, mode: Mode) {
    self.app = app
    self.mode = mode
  }

  var limits: TollConfig.Blocks { app.config.blocks }

  public var title: String {
    switch mode {
    case .setup(let returning): returning ? Copy.BlockEditor.returningTitle : Copy.BlockEditor.setupTitle
    case .new, .edit: Copy.BlockEditor.newTitle
    }
  }

  public var isSetup: Bool { if case .setup = mode { true } else { false } }
  public var overLimit: Bool { !BlockLimits.fits(tokenCount: refs.count, otherBlocksTokenCount: otherTokens, config: limits) }
  public var canFinish: Bool { !refs.isEmpty && !overLimit && !isSaving }
  public var hasChanges: Bool {
    guard let original else { return !refs.isEmpty }
    return original.appRefs != refs || original.schedule != schedule || (original.name ?? "") != name
  }

  public func load() async {
    if case .edit(let id) = mode, let block = try? await app.deps.store.blocks().first(where: { $0.id == id }) {
      original = block
      schedule = block.schedule
      name = block.name ?? ""
      selection = TokenRegistry().selection(for: block.appRefs)
    } else {
      pickerPresented = true
    }
    otherTokens = await app.deps.blocks.tokenCount(excluding: original?.id)
    await loadTags()
  }

  private func selectionChanged() async {
    let result = app.deps.blocks.refs(for: selection)
    refs = result.refs
    kinds = result.kinds
    await loadTags()
  }

  private func loadTags() async {
    let apps = (try? await app.deps.store.apps()) ?? []
    tags = Dictionary(uniqueKeysWithValues: apps.compactMap { app in app.tag.map { (app.appRef, $0) } })
  }

  public func remove(_ ref: AppRef) {
    let registry = TokenRegistry()
    let remaining = refs.filter { $0 != ref }
    selection = registry.selection(for: remaining)
  }

  public func choose(_ kind: Schedule.Kind) {
    if kind == .custom {
      customSheetPresented = true
    } else {
      schedule = .preset(kind, presets: limits.presets)
    }
  }

  public func setTag(_ tag: Tag, for ref: AppRef) async {
    try? await app.deps.blocks.setTag(tag, for: ref)
    tags[ref] = tag
  }

  private func block() -> StoredBlock {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return StoredBlock(
      id: original?.id ?? .make(), name: trimmed.isEmpty ? nil : trimmed, schedule: schedule, appRefs: refs,
      createdAt: original?.createdAt ?? app.deps.clock.now)
  }

  /// Saves and records the change; the shield applies on Done (flows §5).
  @discardableResult
  public func done() async -> Bool {
    guard canFinish else { return false }
    isSaving = true
    defer { isSaving = false }
    do {
      try await app.deps.blocks.save(block(), kinds: kinds)
      return true
    } catch {
      return false
    }
  }

  /// "Add another block": the finished block becomes a compact row above, the picker opens again.
  public func addAnother() async {
    guard await done() else { return }
    finished.append(block())
    original = nil
    selection = FamilyActivitySelection()
    schedule = .always
    name = ""
    otherTokens = await app.deps.blocks.tokenCount(excluding: nil)
    pickerPresented = true
  }

  /// Compact rows collapse into one line on a second Add another (design §4.3).
  public var compactSummary: String? {
    guard finished.count >= 2 else { return nil }
    let labels = finished.map { Copy.Schedules.label($0.schedule).components(separatedBy: Copy.middleDot)[0] }
    return Copy.BlockEditor.compactSummary(finished.count, schedules: labels.joined(separator: ", "))
  }
}
