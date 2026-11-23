@preconcurrency import FamilyControls
@preconcurrency import ManagedSettings
import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// Block · apps picked: iOS's own rows, the counts against the limit, and Done (off over it).
struct BlockAppsView: View {
  @Bindable var model: BlockEditorModel
  @Environment(\.dismiss) private var dismiss
  @State private var picking = false

  var body: some View {
    let limits = model.limits()
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ScreenTitle(Copy.Blocks.apps, kind: .pushed)
        Card {
          ForEach(Array(model.selection.categoryTokens), id: \.self) { token in
            Label(token).labelStyle(AppRowLabelStyle(detail: Copy.Blocks.wholeCategory))
          }
          ForEach(Array(model.selection.applicationTokens), id: \.self) { token in
            Label(token).labelStyle(AppRowLabelStyle())
          }
          ForEach(Array(model.selection.webDomainTokens), id: \.self) { token in
            Label(token).labelStyle(AppRowLabelStyle(detail: Copy.Blocks.website))
          }
          ChooseMoreRow(
            Blocklist.isEmpty(model.selection) ? Copy.Setup.chooseApps : Copy.Setup.chooseMore
          ) { picking = true }
        }
        .padding(.top, 20)
        HStack {
          Text(Copy.Blocks.thisBlock(Blocklist.items(model.selection)))
            .tollType(.detail, TollColor.label2)
          Spacer(minLength: 8)
          Text(Copy.Blocks.allBlocks(limits.appsUsed, of: limits.appsMax))
            .tollType(
              limits.appsOver > 0 ? .trailing : .detail,
              limits.appsOver > 0 ? TollColor.warn : TollColor.label2)
        }
        .padding(.horizontal, 4)
        .padding(.top, TollSpacing.underCard)
        CapacityBar(used: limits.appsUsed, of: limits.appsMax)
          .padding(.horizontal, 4)
          .padding(.top, 8)
        if limits.appsOver > 0 {
          NoteCard(
            Copy.Blocks.overLimit(limits.appsMax, remove: limits.appsOver),
            severity: .broken
          )
          .padding(.top, 12)
        }
      }
      .tollGutter()
      .padding(.bottom, 24)
    }
    .background(TollColor.bg)
    .animation(Motion.stateChange, value: limits.appsOver)
    .tollBottomBar {
      PrimaryButton(Copy.Setup.done) { dismiss() }
        .disabled(limits.appsOver > 0 || Blocklist.isEmpty(model.selection))
    }
    .tollPushed(Copy.Blocks.apps)
    .toolbar(.hidden, for: .tabBar)
    .familyActivityPicker(isPresented: $picking, selection: $model.selection)
  }
}
