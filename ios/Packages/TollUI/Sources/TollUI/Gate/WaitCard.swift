import SwiftUI
import TollCore

/// The countdown half of the wait card (design §3.7).
public struct WaitCountdown {
  public var remaining: TimeInterval
  /// "Wait 3 of today · next wait 8 min" (`Copy.Wait.line`).
  public var line: String
  public var cancelTitle: String
  public var onCancel: () -> Void

  public init(
    remaining: TimeInterval, line: String, cancelTitle: String, onCancel: @escaping () -> Void
  ) {
    self.remaining = remaining
    self.line = line
    self.cancelTitle = cancelTitle
    self.onCancel = onCancel
  }
}

/// The session picker half (design §3.8, §4.10).
public struct SessionChoice {
  public var question: String
  /// Session lengths in minutes; the chips read `Copy.minutes(_:)`.
  public var options: [Int]
  public var selection: Binding<Int>
  public var note: String
  public var onOpen: () -> Void

  public init(
    question: String, options: [Int], selection: Binding<Int>, note: String,
    onOpen: @escaping () -> Void
  ) {
    self.question = question
    self.options = options
    self.selection = selection
    self.note = note
    self.onOpen = onOpen
  }
}

/// First-wait naming (design §3.9). Shown only while the app ref has no tag.
public struct WaitNaming {
  public var question: String
  public var note: String
  public var tags: [Tag]
  public var selection: Binding<Tag?>

  public init(question: String, note: String, tags: [Tag] = Tag.allCases, selection: Binding<Tag?>)
  {
    self.question = question
    self.note = note
    self.tags = tags
    self.selection = selection
  }
}

/// The gate's card. Both halves are always laid out so the countdown-to-picker swap keeps the card's
/// frame and only crossfades (design §2.5, §4.10). `title` and `openLabel` are views because the app's
/// name comes from the system `Label(token)`, which Toll cannot read as text.
public struct WaitCard<Title: View, OpenLabel: View>: View {
  let countdown: WaitCountdown?
  let session: SessionChoice
  let naming: WaitNaming?
  let title: Title
  let openLabel: OpenLabel
  @State private var namingCollapsed = false
  @Environment(\.displayScale) private var displayScale

  /// Pass `countdown` while the wait runs and nil once it ends (or for a free pass). Keep passing
  /// `naming` until the card goes away: the section collapses itself once a tag is chosen.
  public init(
    countdown: WaitCountdown?, session: SessionChoice, naming: WaitNaming? = nil,
    @ViewBuilder title: () -> Title, @ViewBuilder openLabel: () -> OpenLabel
  ) {
    self.countdown = countdown
    self.session = session
    self.naming = naming
    self.title = title()
    self.openLabel = openLabel()
  }

  private var showsCountdown: Bool { countdown != nil }
  private var chosenTag: Tag? { naming.flatMap { $0.selection.wrappedValue } }

  public var body: some View {
    VStack(spacing: 0) {
      title
        .font(TollFont.title)
        .foregroundStyle(TollColor.label)
        .lineLimit(1)
        .padding(.top, 24)
        .accessibilityAddTraits(.isHeader)
      ZStack {
        countdownView(countdown ?? Self.placeholder)
          .opacity(showsCountdown ? 1 : 0)
          .accessibilityHidden(!showsCountdown)
          .allowsHitTesting(showsCountdown)
        pickerView
          .opacity(showsCountdown ? 0 : 1)
          .accessibilityHidden(showsCountdown)
          .allowsHitTesting(!showsCountdown)
      }
      .animation(Motion.movement, value: showsCountdown)
      if let naming, !namingCollapsed {
        namingView(naming)
          .transition(.opacity)
      }
    }
    .padding(.horizontal, TollSpacing.cardPadding)
    .padding(.bottom, TollSpacing.cardPadding)
    .frame(maxWidth: .infinity)
    .background(
      TollColor.bg, in: RoundedRectangle(cornerRadius: TollRadius.waitCard, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: TollRadius.waitCard, style: .continuous)
        .strokeBorder(TollColor.separator, lineWidth: 1 / displayScale)
    }
    .sensoryFeedback(Haptic.light.feedback, trigger: showsCountdown) { wasCounting, isCounting in
      wasCounting && !isCounting
    }
    .onChange(of: chosenTag) { _, tag in
      guard tag != nil else { return }
      // The chosen chip fills and the others fade first; then the section closes up.
      withAnimation(Motion.movement.delay(Motion.Duration.stateChange)) {
        namingCollapsed = true
      }
    }
  }

  private static var placeholder: WaitCountdown {
    WaitCountdown(remaining: 0, line: "", cancelTitle: "", onCancel: {})
  }

  private func countdownView(_ countdown: WaitCountdown) -> some View {
    VStack(spacing: 0) {
      HeroNumber(Self.clock(countdown.remaining), countsDown: true)
        .padding(.top, 28)
        .accessibilityLabel(Self.spokenRemaining(countdown.remaining))
        .accessibilityAddTraits(.updatesFrequently)
      Text(countdown.line)
        .tollText(.subhead)
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .padding(.top, 12)
      QuietButton(countdown.cancelTitle, action: countdown.onCancel)
        .padding(.top, 12)
    }
    .frame(maxWidth: .infinity)
  }

  private var pickerView: some View {
    VStack(spacing: 12) {
      Text(session.question)
        .tollText(.subhead)
        .padding(.top, 20)
      FlowLayout(spacing: 8) {
        ForEach(session.options, id: \.self) { minutes in
          ChoiceChip(Copy.minutes(minutes), isSelected: session.selection.wrappedValue == minutes) {
            session.selection.wrappedValue = minutes
          }
        }
      }
      Text(session.note)
        .tollText(.caption)
        .multilineTextAlignment(.center)
      PrimaryButton(action: session.onOpen) { openLabel }
        .padding(.top, 4)
    }
    .frame(maxWidth: .infinity)
  }

  private func namingView(_ naming: WaitNaming) -> some View {
    VStack(spacing: 8) {
      Hairline()
        .padding(.bottom, 8)
      Text(naming.question)
        .font(TollFont.subheadMedium)
        .foregroundStyle(TollColor.label)
        .accessibilityAddTraits(.isHeader)
      Text(naming.note)
        .tollText(.micro)
        .multilineTextAlignment(.center)
      TagChips(tags: naming.tags, selection: naming.selection)
    }
    .padding(.top, 16)
  }

  static func clock(_ remaining: TimeInterval) -> String {
    let total = max(0, Int(remaining.rounded(.up)))
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  /// VoiceOver hears the time in 30 s steps, rounded up so it never sounds shorter than it is.
  static func spokenRemaining(_ remaining: TimeInterval) -> String {
    let total = max(0, Int(remaining.rounded(.up)))
    let stepped = Int((Double(total) / 30).rounded(.up)) * 30
    return Copy.Wait.remainingAccessibility(minutes: stepped / 60, seconds: stepped % 60)
  }
}

#Preview("Wait card") {
  ZStack {
    WaitOverlayBackdrop()
    WaitCard(
      countdown: WaitCountdown(
        remaining: 161, line: Copy.Wait.line(number: 3, nextMinutes: 8),
        cancelTitle: Copy.Wait.cancel, onCancel: {}),
      session: SessionChoice(
        question: Copy.SessionPicker.question, options: [5, 10, 15], selection: .constant(10),
        note: Copy.SessionPicker.note, onOpen: {}),
      naming: WaitNaming(
        question: Copy.Wait.namingQuestion, note: Copy.Wait.namingNote, selection: .constant(nil))
    ) {
      Text(Copy.Tags.display(.instagram))
    } openLabel: {
      Text(Copy.SessionPicker.open(Copy.Tags.display(.instagram)))
    }
    .tollGutter()
  }
}
