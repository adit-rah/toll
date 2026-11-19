import SwiftUI
import TollCore
import TollUI

/// Every setup screen's frame: the progress bar in the navigation bar, so the title sits at one
/// position on every screen (spec §7), the content beneath it, and the actions pinned at the bottom.
struct SetupPage<Content: View, Actions: View>: View {
  let step: Int?
  let title: String
  var subtitle: String? = nil
  @ViewBuilder let content: Content
  @ViewBuilder let actions: Actions

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: TollSpacing.groupGap) {
        VStack(alignment: .leading, spacing: 12) {
          ScreenTitle(title)
          if let subtitle { SetupLine(subtitle, .subhead) }
        }
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .tollGutter()
      .padding(.bottom, TollSpacing.sectionGap)
    }
    .background(TollColor.bg)
    .tollBottomBar(background: TollColor.bg) {
      VStack(spacing: TollSpacing.labelGap) { actions }
    }
    .navigationBarTitleDisplayMode(.inline)
    // Kept even when empty (Welcome, Ready), so the title sits at one position on every screen.
    .toolbar(.visible, for: .navigationBar)
    .toolbar {
      if let step {
        ToolbarItem(placement: .principal) {
          ProgressSegments(
            count: SetupModel.Step.questions, current: step - 1,
            accessibilityLabel: Copy.Setup.step(step, of: SetupModel.Step.questions)
          )
          .frame(width: 160)
        }
      }
    }
  }
}

/// A line of the page's body text: `body`, wraps, never truncates.
struct SetupLine: View {
  let text: String
  var token: TollText = .body

  init(_ text: String, _ token: TollText = .body) {
    self.text = text
    self.token = token
  }

  var body: some View {
    Text(text)
      .tollText(token)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
