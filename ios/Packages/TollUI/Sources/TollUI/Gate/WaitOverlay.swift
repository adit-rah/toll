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
    .accessibilityHidden(true)
  }
}

/// Design §3.7: the backdrop ramps in over 200 ms and the card rises 24 pt into place on the spring,
/// with its top 180 pt from the top of the screen. Remove the overlay with
/// `.tollTransition(Motion.waitCardExit)`.
public struct WaitOverlay<Card: View>: View {
  let announcesStart: Bool
  let card: Card
  @State private var backdropShown = false
  @State private var cardShown = false

  /// `announcesStart` plays the `.light` haptic for a wait that has just begun, not for one Toll is
  /// reopening into.
  public init(announcesStart: Bool, @ViewBuilder card: () -> Card) {
    self.announcesStart = announcesStart
    self.card = card()
  }

  public var body: some View {
    ZStack(alignment: .top) {
      WaitOverlayBackdrop()
        .opacity(backdropShown ? 1 : 0)
      // A scroll view only so a card taller than the screen (accessibility sizes) stays reachable;
      // at normal sizes it does not bounce.
      ScrollView {
        card
          .tollGutter()
          .opacity(cardShown ? 1 : 0)
          .reducibleOffset(y: cardShown ? 0 : 24)
          .padding(.top, TollSpacing.waitCardTop)
          .padding(.bottom, TollSpacing.gutter)
      }
      .scrollBounceBehavior(.basedOnSize)
      .scrollIndicators(.hidden)
      .ignoresSafeArea(.container, edges: .top)
    }
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isModal)
    .onAppear {
      withAnimation(Motion.stateChange) { backdropShown = true }
      withAnimation(Motion.spring) { cardShown = true }
      if announcesStart { Haptic.light.play() }
    }
  }
}
