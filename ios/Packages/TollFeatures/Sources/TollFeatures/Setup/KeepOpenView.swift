@preconcurrency import FamilyControls
@preconcurrency import ManagedSettings
import SwiftUI
import TollCore
import TollUI

/// Setup 5 (spec §7). The app cannot tell which app is which, so the user picks; whatever they pick is
/// the list (spec §5).
struct KeepOpenView: View {
  @Bindable var model: SetupModel
  @State private var picking = false

  var body: some View {
    SetupPage(step: SetupModel.Step.keepOpen.number, title: Copy.Setup.keepOpenTitle) {
      SetupLine(Copy.Setup.keepOpenLine, .subhead)
      KeptList(selection: model.selection)
      if !model.selection.categoryTokens.isEmpty {
        SetupLine(Copy.Setup.categoriesNotKept, .caption)
      }
    } actions: {
      if hasChoice {
        PrimaryButton(Copy.Setup.done) { model.keepOpenChosen() }
        QuietButton(Copy.Setup.chooseAgain) { picking = true }
      } else {
        PrimaryButton(Copy.Setup.choose) { picking = true }
      }
    }
    .familyActivityPicker(isPresented: $picking, selection: $model.selection)
  }

  private var hasChoice: Bool {
    !model.selection.applicationTokens.isEmpty || !model.selection.webDomainTokens.isEmpty
  }
}

/// The chosen apps and sites, with their system names and icons (`Label(token)`), never strings.
struct KeptList: View {
  let selection: FamilyActivitySelection

  var body: some View {
    VStack(alignment: .leading, spacing: TollSpacing.labelGap) {
      ForEach(Array(selection.applicationTokens.enumerated()), id: \.offset) { index, token in
        Label(token)
          .staggeredAppearance(
            index: index, step: Motion.PickerRows.stagger, rise: Motion.PickerRows.rise)
      }
      ForEach(Array(selection.webDomainTokens.enumerated()), id: \.offset) { index, token in
        Label(token)
          .staggeredAppearance(
            index: selection.applicationTokens.count + index, step: Motion.PickerRows.stagger,
            rise: Motion.PickerRows.rise)
      }
    }
    .font(TollFont.body)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
