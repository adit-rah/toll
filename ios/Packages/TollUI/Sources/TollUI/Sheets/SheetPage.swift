import SwiftUI

/// A sheet laid out as the canvas draws one: `surface` behind, the title 37 pt from the top (under
/// iOS's grabber), the content, and the actions at the bottom on the same line as a screen's main
/// button. The sheet is the board's height at the default text size, grows with larger text, and
/// opens full height at accessibility sizes, where the page scrolls.
public struct SheetPage<Content: View, Actions: View>: View {
  let height: CGFloat
  let endsWithLink: Bool
  let content: Content
  let actions: Actions
  @Environment(\.dynamicTypeSize) private var typeSize

  /// `height` is the board's: 844 minus the sheet's `top`.
  public init(
    height: CGFloat, endsWithLink: Bool = false, @ViewBuilder content: () -> Content,
    @ViewBuilder actions: () -> Actions
  ) {
    self.height = height
    self.endsWithLink = endsWithLink
    self.content = content()
    self.actions = actions()
  }

  public var body: some View {
    GeometryReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          content
          Spacer(minLength: 24)
          actions
        }
        .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .topLeading)
      }
      .scrollBounceBehavior(.basedOnSize)
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
    HomeIndicator.present
      ? (endsWithLink ? -16 : 0)
      : TollSpacing.bottomWithoutIndicator
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
