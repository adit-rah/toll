import SwiftUI
import TollCore
import TollUI

/// Blocks (the design canvas): every block, and a new one. From Settings; Home lists them too.
struct BlocksView: View {
  let model: AppModel
  @State private var editing: BlockRef?

  var body: some View {
    let home = HomeSnapshot(state: model.state, log: [], now: Date(), calendar: .current)
    ScrollView {
      VStack(alignment: .leading, spacing: TollSpacing.groupGap) {
        Text(Copy.Blocks.line).font(TollFont.subhead).foregroundStyle(TollColor.label2)
        BlockList(rows: home.blocks) { editing = BlockRef(id: $0) }
        PrimaryButton(Copy.Blocks.new) { editing = BlockRef(id: nil) }
        Footnote(Copy.Blocks.limits(model.config.blocks.maxApps))
      }
      .tollGutter()
      .padding(.vertical, TollSpacing.groupGap)
    }
    .background(TollColor.bg)
    .navigationTitle(Copy.Blocks.title)
    .sheet(item: $editing) { ref in BlockEditorView(app: model, editing: ref.block) }
  }
}

/// A block to edit, or nil for a new one.
struct BlockRef: Identifiable {
  let block: BlockID?
  var id: String { block?.raw ?? "new" }

  init(id: BlockID?) { block = id }
}
