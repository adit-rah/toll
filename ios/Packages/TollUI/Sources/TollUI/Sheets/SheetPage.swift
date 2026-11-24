import SwiftUI

/// A sheet laid out as the canvas draws one: `surface` behind, the title 37 pt from the top (under
/// iOS's grabber), the content, and the actions at the bottom on the same line as a screen's main
/// button. The sheet is the board's height at the default text size, grows with larger text, and
/// opens full height at accessibility sizes, where the content scrolls and the actions stay pinned
/// under it (design §2.1).
public struct SheetPage<Content: View, Actions: View>: View {
  let height: CGFloat
  let overhang: CGFloat
  let content: Content
  let actions: Actions
  @Environment(\.dynamicTypeSize) private var typeSize

  /// `height` is the board's: 844 minus the sheet's `top`. `overhang` is how far the last action
  /// reaches below the main button's line: 16 for a quiet link, 8 for a footnote.
  public init(
    height: CGFloat, overhang: CGFloat = 0, @ViewBuilder content: () -> Content,
    @ViewBuilder actions: () -> Actions
  ) {
    self.height = height
    self.overhang = overhang
    self.content = content()
    self.actions = actions()
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) { content }
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .padding(.bottom, 24)
      }
      .scrollBounceBehavior(.basedOnSize)
      actions
    }
    .tollGutter()
    .padding(.top, 37)
    .padding(.bottom, bottom)
    .background(TollColor.surface)
    .presentationBackground(TollColor.surface)
    .presentationDragIndicator(.visible)
    .presentationDetents(detents)
  }

  /// As on a screen: the main button's bottom edge on the safe area, a quiet link 16 pt into it.
  private var bottom: CGFloat {
    HomeIndicator.present ? -overhang : TollSpacing.bottomWithoutIndicator
  }

  private var detents: Set<PresentationDetent> {
    if typeSize.isAccessibilitySize { return [.large] }
    let scale = TollType.rowTitle.scale(at: typeSize)
    return [.height(height * max(1, scale))]
  }
}

/// A sheet's title: 24/28 semibold.
public struct SheetTitle: View {
  let text: String

  public init(_ text: String) {
    self.text = text
  }

  public var body: some View {
    Text(text)
      .tollType(.sheetTitle, TollColor.label)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityAddTraits(.isHeader)
  }
}

/// A sheet's sentence: 16/23 in `label2`, 10 pt under the title.
public struct SheetBody: View {
  let text: String

  public init(_ text: String) {
    self.text = text
  }

  public var body: some View {
    Text(text)
      .tollType(.sheetBody, TollColor.label2)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 10)
  }
}
