@preconcurrency import FamilyControls
@preconcurrency import ManagedSettings
import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// Setup 5: the blocklist (decisions D27). The app cannot tell which app is which, so the user picks;
/// whatever they pick is blocked at night and everything else stays open.
struct BlocklistView: View {
  @Bindable var model: SetupModel
  @State private var picking = false

  var body: some View {
    SetupPage(step: SetupModel.Step.blocklist.number, title: Copy.Setup.blockTitle) {
      SetupLine(Copy.Setup.blockLine, .subhead)
      ChosenList(selection: model.selection)
      if Blocklist.items(model.selection) > model.app.config.blocks.maxApps {
        SetupLine(Copy.Setup.tooMany(model.app.config.blocks.maxApps))
      }
    } actions: {
      if Blocklist.isEmpty(model.selection) {
        PrimaryButton(Copy.Setup.choose) { picking = true }
      } else {
        PrimaryButton(Copy.Setup.done) { model.blocklistChosen() }
          .disabled(!model.blocklistReady)
        QuietButton(Copy.Setup.chooseAgain) { picking = true }
      }
    }
    .familyActivityPicker(isPresented: $picking, selection: $model.selection)
  }
}

/// The chosen apps, sites and categories, with their system names and icons (`Label(token)`), never
/// strings.
struct ChosenList: View {
  let selection: FamilyActivitySelection

  var body: some View {
    VStack(alignment: .leading, spacing: TollSpacing.labelGap) {
      ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
        row
          .staggeredAppearance(
            index: index, step: Motion.PickerRows.stagger, rise: Motion.PickerRows.rise)
      }
    }
    .font(TollFont.body)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var rows: [AnyView] {
    selection.categoryTokens.map { AnyView(Label($0)) }
      + selection.applicationTokens.map { AnyView(Label($0)) }
      + selection.webDomainTokens.map { AnyView(Label($0)) }
  }
}
