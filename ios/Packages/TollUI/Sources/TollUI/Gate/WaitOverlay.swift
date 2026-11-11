import SwiftUI

/// The full-screen backdrop behind the wait card: `.regular` material, or opaque `bg` at 94% with
/// Reduce Transparency (design §5). It swallows taps so Home and the tab bar beneath stay inert.
public struct WaitOverlayBackdrop: View {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  public init() {}

  public var body: some View {
    Group {
      if reduceTransparency {
        Rectangle().fill(TollColor.bg.opacity(0.94))
      } else {
        Rectangle().fill(.regularMaterial)
      }
    }
    .ignoresSafeArea()
    .contentShape(Rectangle())
    .accessibilityHidden(true)
  }
}

/// Design §3.7 and §2.5. The backdrop ramps in over 200 ms while the card rises 24 pt into place on
/// the spring; on the way out the card drops 24 pt and both fade in 200 ms. The backdrop and the
/// card are siblings so each gets its own transition: moving them as one would slide the blur too.
public struct WaitOverlay<Card: View>: View {
  let isPresented: Bool
  let card: Card
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// `card` may be empty while `isPresented` is false; the card on screen keeps its last content
  /// until it has faded.
  public init(isPresented: Bool, @ViewBuilder card: () -> Card) {
    self.isPresented = isPresented
    self.card = card()
  }

  public var body: some View {
    ZStack {
      if isPresented {
        WaitOverlayBackdrop()
          .transition(.opacity)
          .zIndex(0)
        WaitCardStage { card }
          .transition(cardTransition)
          .zIndex(1)
      }
    }
    .animation(Motion.stateChange, value: isPresented)
  }

  private var cardTransition: AnyTransition {
    // Reduce Motion keeps the 200 ms crossfade and drops the travel.
    guard !reduceMotion else { return .opacity }
    return .asymmetric(
      insertion: Motion.waitCardExit.animation(Motion.spring), removal: Motion.waitCardExit)
  }
}

/// Places the card a gutter in from each side with its top 180 pt down the screen (design §3.7).
/// When the card is too tall for that (first-wait naming on a small phone, large text) it moves up
/// toward the centre instead of running off the bottom, and scrolls only once it cannot fit at all.
struct WaitCardStage<Card: View>: View {
  let card: Card

  init(@ViewBuilder card: () -> Card) {
    self.card = card()
  }

  var body: some View {
    GeometryReader { proxy in
      let gutter = TollSpacing.horizontalGutter(forWidth: proxy.size.width)
      let lead = max(0, TollSpacing.waitCardTop - proxy.safeAreaInsets.top - gutter)
      ScrollView {
        VStack(spacing: 0) {
          // Takes its full height only while the space below the card is at least as large, so a
          // tall card ends up centred rather than pinned.
          Spacer(minLength: 0)
            .frame(maxHeight: lead)
          card
            .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 0)
        }
        .padding(gutter)
        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
      }
      .scrollBounceBehavior(.basedOnSize)
      .scrollIndicators(.hidden)
    }
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isModal)
  }
}
