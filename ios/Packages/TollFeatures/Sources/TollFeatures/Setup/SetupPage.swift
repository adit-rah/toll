import SwiftUI
import TollCore
import TollUI

/// Every setup screen's frame (the canvas): the 44 pt bar with Apple's back button and the progress
/// segments between it and the right edge, the title 28 pt under the bar, the content, and the
/// actions pinned at the bottom. Screens set their own gaps; the boards differ by screen.
struct SetupPage<Content: View, Actions: View>: View {
  let step: Int?
  let steps: Int
  let title: String
  let eyebrow: String?
  let eyebrowSymbol: TollSymbol?
  let subtitle: String?
  let endsWithLink: Bool
  let content: Content
  let actions: Actions
  @State private var width: CGFloat = 390

  init(
    step: Int?, of steps: Int = SetupModel.Step.questions, title: String, eyebrow: String? = nil,
    eyebrowSymbol: TollSymbol? = nil, subtitle: String? = nil, endsWithLink: Bool = false,
    @ViewBuilder content: () -> Content, @ViewBuilder actions: () -> Actions
  ) {
    self.step = step
    self.steps = steps
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
            // A state's glyph before its eyebrow, as on Tonight (#72): Ready's "done" reads wordless.
            if let eyebrowSymbol {
              StateLine(eyebrow, symbol: eyebrowSymbol, tone: .accent)
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
    .onGeometryChange(for: CGFloat.self) {
      $0.size.width
    } action: {
      width = $0
    }
    .tollBottomBar(endsWithLink: endsWithLink) {
      VStack(spacing: 0) { actions }
    }
    .navigationBarTitleDisplayMode(.inline)
    // Kept even when empty (Ready), so the title sits at one position on every screen.
    .toolbar(.visible, for: .navigationBar)
    .toolbar {
      if let step {
        ToolbarItem(placement: .principal) {
          ProgressSegments(
            count: steps, current: step - 1,
            accessibilityLabel: Copy.Setup.step(step, of: steps)
          )
          .frame(width: progressWidth)
        }
        .sharedBackgroundVisibility(.hidden)
      }
    }
  }

  /// The board's bar: 28 pt for the back button and 14 pt either side of the segments, mirrored on
  /// the right so the segments sit centred.
  private var progressWidth: CGFloat {
    let gutter = TollSpacing.horizontalGutter(forWidth: width)
    return max(120, width - 2 * (gutter + 28 + 14))
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
      Image(symbol: symbol).unredacted().font(.system(size: 12, weight: .bold))
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
