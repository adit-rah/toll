import SwiftUI
import TollCore

/// The countdown half of the wait card (design §3.7).
public struct WaitCountdown {
  /// When the wait is over. The card's clock counts down to it by itself, so this only needs to
  /// change if the end moves.
  public var endsAt: Date
  /// "Wait 3 of today · next wait 8 min" (`Copy.Wait.line`).
  public var line: String
  public var cancelTitle: String
  public var onCancel: () -> Void

  public init(endsAt: Date, line: String, cancelTitle: String, onCancel: @escaping () -> Void) {
    self.endsAt = endsAt
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
  /// When set, "Not now" sits under the primary button, where Cancel is on the countdown half.
  public var onNotNow: (() -> Void)?

  public init(
    question: String, options: [Int], selection: Binding<Int>, note: String,
    onOpen: @escaping () -> Void, onNotNow: (() -> Void)? = nil
  ) {
    self.question = question
    self.options = options
    self.selection = selection
    self.note = note
    self.onOpen = onOpen
    self.onNotNow = onNotNow
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

/// The gate's card. Both halves are always laid out in one shared frame, each with its action on
/// the bottom edge, so the countdown-to-picker swap keeps the card's size and only crossfades
/// (design §2.5, §4.10). `title` and `openLabel` are views because the app's name comes from the
/// system `Label(token)`, which Toll cannot read as text. The card plays no haptics: `GateModel`
/// plays `.light` at the start and end of the wait and `.selection` on naming.
public struct WaitCard<Title: View, OpenLabel: View>: View {
  let countdown: WaitCountdown?
  let session: SessionChoice
  let naming: WaitNaming?
  let title: Title
  let openLabel: OpenLabel
  @State private var namingCollapsed = false
  @State private var lastLine = " "
  @Environment(\.displayScale) private var displayScale

  /// Pass `countdown` while the wait runs and nil once it ends (or for a free pass). The naming
  /// section collapses once its selection is set, and also fades out if `naming` turns nil.
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
  private var showsNaming: Bool { naming != nil && !namingCollapsed }
  private var chosenTag: Tag? { naming.flatMap { $0.selection.wrappedValue } }
  private var outline: RoundedRectangle {
    RoundedRectangle(cornerRadius: TollRadius.waitCard, style: .continuous)
  }

  public var body: some View {
    VStack(spacing: 0) {
      title
        .font(TollFont.title)
        .foregroundStyle(TollColor.label)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityAddTraits(.isHeader)
      SharedFrame {
        countdownHalf
          .opacity(showsCountdown ? 1 : 0)
          .accessibilityHidden(!showsCountdown)
          .allowsHitTesting(showsCountdown)
        pickerHalf
          .opacity(showsCountdown ? 0 : 1)
          .accessibilityHidden(showsCountdown)
          .allowsHitTesting(!showsCountdown)
      }
      .animation(Motion.movement, value: showsCountdown)
    }
    .padding(.top, WaitCardMetrics.top)
    .padding([.horizontal, .bottom], WaitCardMetrics.inset)
    .frame(maxWidth: .infinity)
    .background(TollColor.bg, in: outline)
    .overlay {
      outline.strokeBorder(TollColor.separator, lineWidth: 1 / displayScale)
    }
    .animation(Motion.movement, value: naming == nil)
    .onChange(of: chosenTag) { _, tag in
      guard tag != nil else {
        // A wait that follows another on the same card starts with its naming section open.
        namingCollapsed = false
        return
      }
      // The chosen chip fills and the others fade first; then the section closes up.
      withAnimation(Motion.movement.delay(Motion.Duration.stateChange)) {
        namingCollapsed = true
      }
    }
    .onChange(of: countdown?.line, initial: true) { _, line in
      // The hidden countdown keeps its last line so its height, and with it the card's, does not
      // change at the moment the wait ends.
      if let line { lastLine = line }
    }
  }

  private var countdownHalf: some View {
    VStack(spacing: 0) {
      CountdownClock(endsAt: countdown?.endsAt)
        .padding(.top, WaitCardMetrics.numeralTop)
      Text(countdown?.line ?? lastLine)
        .tollText(.subhead)
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .padding(.top, WaitCardMetrics.numeralToLine)
      if let naming, !namingCollapsed {
        namingSection(naming)
          .padding(.top, WaitCardMetrics.lineToNaming)
          .transition(.opacity)
      }
      Spacer(minLength: showsNaming ? WaitCardMetrics.chipsToAction : WaitCardMetrics.lineToCancel)
      QuietButton(countdown?.cancelTitle ?? Copy.Wait.cancel, action: countdown?.onCancel ?? {})
    }
    .frame(maxWidth: .infinity)
  }

  private var pickerHalf: some View {
    VStack(spacing: 0) {
      Text(session.question)
        .tollText(.subhead)
        .padding(.top, WaitCardMetrics.titleToQuestion)
      // Two spacers share whatever height the countdown half adds, so the chips stay centred
      // between the question and the button instead of leaving one large gap.
      Spacer(minLength: WaitCardMetrics.questionToChips)
      FlowLayout(spacing: WaitCardMetrics.chipGap, lineSpacing: WaitCardMetrics.chipLineSpacing) {
        ForEach(session.options, id: \.self) { minutes in
          ChoiceChip(Copy.minutes(minutes), isSelected: session.selection.wrappedValue == minutes) {
            session.selection.wrappedValue = minutes
          }
        }
      }
      SentenceText(session.note)
        .tollText(.caption)
        .padding(.top, WaitCardMetrics.noteGap)
      Spacer(minLength: WaitCardMetrics.noteToButton)
      PrimaryButton(action: session.onOpen) { openLabel }
      if let onNotNow = session.onNotNow {
        QuietButton(Copy.SessionPicker.notNow, action: onNotNow)
          .padding(.top, WaitCardMetrics.noteGap)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func namingSection(_ naming: WaitNaming) -> some View {
    VStack(spacing: 0) {
      Hairline()
      Text(naming.question)
        .font(TollFont.subheadMedium)
        .foregroundStyle(TollColor.label)
        .accessibilityAddTraits(.isHeader)
        .padding(.top, WaitCardMetrics.hairlineToQuestion)
      // `detail`, not `micro`: this line tells people what friends will see, and tertiary label
      // at 11 pt is too faint to carry that.
      SentenceText(naming.note)
        .tollText(.detail)
        .padding(.top, 2)
      TagChips(tags: naming.tags, selection: naming.selection, playsHaptic: false)
        .padding(.top, WaitCardMetrics.noteGap)
    }
  }
}

/// One line where it fits; otherwise the break falls between sentences instead of leaving the last
/// word alone on a centred second line.
private struct SentenceText: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    ViewThatFits(in: .horizontal) {
      Text(text).lineLimit(1)
      Text(text.replacingOccurrences(of: ". ", with: ".\n"))
    }
    .multilineTextAlignment(.center)
  }
}

#Preview("Wait card") {
  ZStack {
    WaitOverlayBackdrop()
    WaitCard(
      countdown: WaitCountdown(
        endsAt: Date.now.addingTimeInterval(161), line: Copy.Wait.line(number: 3, nextMinutes: 8),
        cancelTitle: Copy.Wait.cancel, onCancel: {}),
      session: SessionChoice(
        question: Copy.SessionPicker.question, options: [5, 10, 15], selection: .constant(10),
        note: Copy.SessionPicker.note, onOpen: {}, onNotNow: {}),
      naming: WaitNaming(
        question: Copy.Wait.namingQuestion, note: Copy.Wait.namingNote, selection: .constant(nil))
    ) {
      Text(Copy.Tags.display(.instagram))
    } openLabel: {
      Text(Copy.SessionPicker.open(Copy.Tags.display(.instagram)))
    }
    .padding(TollSpacing.gutter)
  }
}
