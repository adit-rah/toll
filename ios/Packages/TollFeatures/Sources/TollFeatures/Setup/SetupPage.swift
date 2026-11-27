import SwiftUI
import TollCore
import TollUI

/// Every setup screen's frame (the canvas): the 44 pt bar with Apple's back button, the title 28 pt
/// under the bar, the content, and the actions pinned at the bottom. Screens set their own gaps;
/// the boards differ by screen. The progress segments aren't the page's: the flow fixes them over
/// its bar (`setupProgress`), so they stay still while pages slide.
struct SetupPage<Content: View, Actions: View>: View {
  let title: String
  let eyebrow: String?
  let eyebrowSymbol: TollSymbol?
  let subtitle: String?
  let endsWithLink: Bool
  let content: Content
  let actions: Actions

  init(
    title: String, eyebrow: String? = nil,
    eyebrowSymbol: TollSymbol? = nil, subtitle: String? = nil, endsWithLink: Bool = false,
    @ViewBuilder content: () -> Content, @ViewBuilder actions: () -> Actions
  ) {
    self.title = title
    self.eyebrow = eyebrow
    self.eyebrowSymbol = eyebrowSymbol
    self.subtitle = subtitle
    self.endsWithLink = endsWithLink
    self.content = content()
    self.actions = actions()
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        if let eyebrow {
          Group {
            // A state's glyph over its eyebrow, as on Tonight (#72, #76): Ready's "done" reads
            // wordless.
            if let eyebrowSymbol {
              VStack(alignment: .leading, spacing: 4) {
                StateMark(eyebrowSymbol, tone: .accent).padding(.leading, -8)
                Text(eyebrow).tollType(.eyebrow, TollColor.label2)
              }
            } else {
              Text(eyebrow).tollType(.eyebrow, TollColor.label2)
            }
          }
          .padding(.top, TollSpacing.setupTitleGap)
          Text(title)
            .tollType(.setupTitle, TollColor.label)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 8)
        } else {
          ScreenTitle(title)
        }
        if let subtitle {
          SetupLine(subtitle).padding(.top, TollSpacing.titleToLine)
        }
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .tollGutter()
      .padding(.bottom, 24)
    }
    .scrollBounceBehavior(.basedOnSize)
    .background(TollColor.bg)
    .tollBottomBar(endsWithLink: endsWithLink) {
      VStack(spacing: 0) { actions }
    }
    .navigationBarTitleDisplayMode(.inline)
    // Kept even when empty (Ready), so the title sits at one position on every screen.
    .toolbar(.visible, for: .navigationBar)
  }
}

/// A line under a setup title: 15/21 in `label2`, wraps, never truncates.
struct SetupLine: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .tollType(.body, TollColor.label2)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A permission's state at the end of its row, as Settings words it: "Off" in the warn colour,
/// "Always" in green with a tick, anything else grey. Never colour alone: the word says it.
struct PermissionState: View {
  enum Tone {
    case good, bad, neutral
  }

  let text: String
  let tone: Tone

  var body: some View {
    // Every tone has a glyph, so the colour never carries the meaning alone (#72, C4).
    HStack(spacing: 5) {
      Image(symbol: symbol).unredacted().tollGlyph(12, weight: .bold)
        .accessibilityHidden(true)
      Text(text)
    }
    .tollType(.action, color)
  }

  private var symbol: TollSymbol {
    switch tone {
    case .good: .done
    case .bad: .broken
    case .neutral: .degraded
    }
  }

  private var color: Color {
    switch tone {
    case .good: TollColor.ok
    case .bad: TollColor.warn
    case .neutral: TollColor.label2
    }
  }
}
