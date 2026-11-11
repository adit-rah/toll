import SwiftUI
import TollCore
import TollData
import TollUI

/// Blocks (design §4.6): one row per block; removing one is shown to friends.
struct BlocksView: View {
  let app: AppModel
  // Nil until the store answers, so the empty line never flashes before the rows arrive.
  @State private var blocks: [StoredBlock]?
  @State private var removing: StoredBlock?

  var body: some View {
    List {
      Section {
        if let blocks, blocks.isEmpty {
          Text(Copy.Home.nothingBlocked).font(TollFont.body).foregroundStyle(TollColor.label2)
        }
        ForEach(blocks ?? []) { block in
          NavigationLink(value: HomeRoute.editBlock(block.id)) {
            // The link draws the chevron.
            BlockRow(schedule: Copy.Schedules.label(block.schedule), showsChevron: false) {
              AppIconCluster(block.appRefs)
            } names: {
              AppNames(block.appRefs)
            }
          }
          .swipeActions {
            Button(Copy.Blocks.remove, role: .destructive) { removing = block }
          }
        }
      } footer: {
        Text(Copy.Blocks.header).tollText(.caption)
      }
    }
    .navigationTitle(Copy.Blocks.title)
    .navigationBarTitleDisplayMode(.inline)
    .tollBottomBar {
      NavigationLink(value: HomeRoute.newBlock) {
        Text(Copy.Blocks.add)
      }
      .buttonStyle(.tollPrimary)
      .disabled(!BlockLimits.canAddBlock(existing: blocks?.count ?? 0, config: app.config.blocks))
    }
    // `presenting` hands the block to the button; reading `removing` there is too late, because the
    // dialog clears it as it closes.
    .confirmationDialog(
      removing.map { Copy.Blocks.removeConfirm(name(of: $0)) } ?? "",
      isPresented: .init(get: { removing != nil }, set: { if !$0 { removing = nil } }),
      titleVisibility: .visible, presenting: removing
    ) { block in
      Button(Copy.Blocks.remove, role: .destructive) {
        Haptics.warning()
        Task { try? await app.deps.blocks.remove(block.id) }
      }
      Button(Copy.Blocks.keep, role: .cancel) {}
    }
    .task {
      do {
        for try await value in app.deps.store.observeBlocks() {
          if blocks == nil {
            blocks = value
          } else {
            withAnimation(Motion.movement) { blocks = value }
          }
        }
      } catch {}
    }
  }

  /// The confirmation names the block by its user-only name, else its schedule: Toll cannot read the
  /// system's app names as text (spec §6).
  private func name(of block: StoredBlock) -> String {
    block.name ?? Copy.Schedules.label(block.schedule)
  }
}

/// Every push in the Home stack is a value on its path, declared once at the stack's root. A
/// view-destination link in the middle (Settings to Blocks used one) left the path a screen short of
/// what was showing, so popping New block and then going back opened New block again.
enum HomeRoute: Hashable {
  case settings
  case blocks
  case newBlock
  case editBlock(BlockRef)
}
