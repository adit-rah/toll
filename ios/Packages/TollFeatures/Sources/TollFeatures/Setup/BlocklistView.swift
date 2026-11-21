@preconcurrency import FamilyControls
@preconcurrency import ManagedSettings
import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// Setup 4 (the canvas, D27): the apps that keep the user up. Whatever they pick is blocked at night;
/// everything else stays open.
struct BlocklistView: View {
  @Bindable var model: SetupModel
  @State private var picking = false

  var body: some View {
    SetupPage(
      step: SetupModel.Step.blocklist.number, title: Copy.Setup.blockTitle,
      subtitle: Copy.Setup.blockLine
    ) {
      Card {
        ForEach(rows.indices, id: \.self) { index in
          rows[index]
            .staggeredAppearance(
              index: index, step: Motion.PickerRows.stagger, rise: Motion.PickerRows.rise)
        }
        ChooseMoreRow(
          Blocklist.isEmpty(model.selection) ? Copy.Setup.chooseApps : Copy.Setup.chooseMore
        ) { picking = true }
      }
      .padding(.top, 24)
      if Blocklist.items(model.selection) > model.app.config.blocks.maxApps {
        NoteCard(
          Copy.Setup.tooMany(model.app.config.blocks.maxApps), severity: .broken
        )
        .padding(.top, 12)
      }
      Footnote(Copy.Setup.pickerNote).padding(.top, TollSpacing.underCard)
    } actions: {
      PrimaryButton(Copy.Setup.continue) { model.blocklistChosen() }
        .disabled(!model.blocklistReady)
    }
    .familyActivityPicker(isPresented: $picking, selection: $model.selection)
  }

  /// The system's own names and icons (`Label(token)`), never strings: the app can't tell which app
  /// is which.
  private var rows: [AnyView] {
    model.selection.categoryTokens.map {
      AnyView(Label($0).labelStyle(AppRowLabelStyle(detail: Copy.Blocks.wholeCategory)))
    }
      + model.selection.applicationTokens.map {
        AnyView(Label($0).labelStyle(AppRowLabelStyle()))
      }
      + model.selection.webDomainTokens.map {
        AnyView(Label($0).labelStyle(AppRowLabelStyle(detail: Copy.Blocks.website)))
      }
  }
}
