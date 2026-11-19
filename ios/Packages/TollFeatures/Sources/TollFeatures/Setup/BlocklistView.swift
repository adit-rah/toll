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
            .font(TollFont.bodyMedium)
            .foregroundStyle(TollColor.label)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .staggeredAppearance(
              index: index, step: Motion.PickerRows.stagger, rise: Motion.PickerRows.rise)
        }
        Button {
          picking = true
        } label: {
          Label(
            Blocklist.isEmpty(model.selection) ? Copy.Setup.chooseApps : Copy.Setup.chooseMore,
            systemImage: "plus"
          )
          .font(TollFont.bodyMedium)
          .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        }
        .foregroundStyle(TollColor.accent)
      }
      if Blocklist.items(model.selection) > model.app.config.blocks.maxApps {
        SetupLine(Copy.Setup.tooMany(model.app.config.blocks.maxApps))
      }
      Footnote(Copy.Setup.pickerNote)
    } actions: {
      PrimaryButton(Copy.Setup.continue) { model.blocklistChosen() }
        .disabled(!model.blocklistReady)
    }
    .familyActivityPicker(isPresented: $picking, selection: $model.selection)
  }

  /// The system's own names and icons (`Label(token)`), never strings: the app can't tell which app
  /// is which.
  private var rows: [AnyView] {
    model.selection.categoryTokens.map { AnyView(Label($0)) }
      + model.selection.applicationTokens.map { AnyView(Label($0)) }
      + model.selection.webDomainTokens.map { AnyView(Label($0)) }
  }
}
