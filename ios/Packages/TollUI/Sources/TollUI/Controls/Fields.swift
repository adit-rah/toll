import SwiftUI

/// The 56 pt filled field of the sign-in and setup screens (design §4.3). The default fill reads on
/// `bg`; pass `surface` on grouped backgrounds. Apply `.keyboardType`, `.textContentType` and
/// `.submitLabel` outside; they reach the text field.
public struct FilledField<Trailing: View>: View {
  let placeholder: String
  @Binding var text: String
  let fill: Color
  let isFocused: FocusState<Bool>.Binding?
  let trailing: Trailing

  public init(
    _ placeholder: String, text: Binding<String>, fill: Color = TollColor.surfaceRaised,
    isFocused: FocusState<Bool>.Binding? = nil, @ViewBuilder trailing: () -> Trailing
  ) {
    self.placeholder = placeholder
    _text = text
    self.fill = fill
    self.isFocused = isFocused
    self.trailing = trailing()
  }

  public var body: some View {
    HStack(spacing: 8) {
      if let isFocused {
        field.focused(isFocused)
      } else {
        field
      }
      trailing
    }
    .padding(.horizontal, 16)
    .frame(minHeight: 56)
    .background(fill, in: RoundedRectangle(cornerRadius: TollRadius.field, style: .continuous))
    .tint(TollColor.accent)
  }

  private var field: some View {
    TextField(placeholder, text: $text)
      .font(TollFont.body)
      .foregroundStyle(TollColor.label)
  }
}

extension FilledField where Trailing == EmptyView {
  public init(
    _ placeholder: String, text: Binding<String>, fill: Color = TollColor.surfaceRaised,
    isFocused: FocusState<Bool>.Binding? = nil
  ) {
    self.init(placeholder, text: text, fill: fill, isFocused: isFocused) { EmptyView() }
  }
}

/// Six 60 pt code boxes backed by one hidden text field, so one-time-code autofill and paste land in
/// one place (design §4.3). Advancing and submitting stay with the caller through `onComplete`.
/// Bump `shakeTrigger` on a wrong code: the row shakes ±6 pt twice over 300 ms and clears on the way
/// back (a dim and clear with Reduce Motion).
public struct CodeBoxes: View {
  @Binding var code: String
  let length: Int
  let shakeTrigger: Int
  let accessibilityText: String
  let fill: Color
  let onComplete: (String) -> Void
  @FocusState private var focused: Bool
  @State private var shakeOffset: CGFloat = 0
  @State private var dimmed = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// `accessibilityLabel` names the field for VoiceOver (`Copy.Code.title`).
  public init(
    code: Binding<String>, length: Int = 6, shakeTrigger: Int = 0, accessibilityLabel: String,
    fill: Color = TollColor.surfaceRaised, onComplete: @escaping (String) -> Void
  ) {
    _code = code
    self.length = length
    self.shakeTrigger = shakeTrigger
    self.accessibilityText = accessibilityLabel
    self.fill = fill
    self.onComplete = onComplete
  }

  public var body: some View {
    HStack(spacing: 8) {
      ForEach(0..<length, id: \.self) { index in
        box(index)
      }
    }
    .accessibilityHidden(true)
    .overlay {
      // Clear text and caret: the boxes draw the digits; the field only takes input.
      TextField("", text: $code)
        .textContentType(.oneTimeCode)
        .keyboardType(.numberPad)
        .focused($focused)
        .foregroundStyle(.clear)
        .tint(.clear)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(accessibilityText)
        .accessibilityValue(code)
    }
    .offset(x: shakeOffset)
    .opacity(dimmed ? 0.4 : 1)
    .onAppear { focused = true }
    .onChange(of: code) { _, newValue in
      // Autofill and paste can bring spaces or dashes; keep digits only, then complete on the last one.
      let clean = String(newValue.filter { $0.isASCII && $0.isNumber }.prefix(length))
      if clean != newValue {
        code = clean
      } else if clean.count == length {
        onComplete(clean)
      }
    }
    .onChange(of: shakeTrigger) {
      shake()
    }
  }

  private func box(_ index: Int) -> some View {
    let characters = Array(code)
    let isActive = focused && index == characters.count && characters.count < length
    return ZStack {
      RoundedRectangle(cornerRadius: TollRadius.field, style: .continuous)
        .fill(fill)
      if index < characters.count {
        Text(String(characters[index]))
          .font(.system(size: 28, weight: .semibold).monospacedDigit())
          .foregroundStyle(TollColor.label)
          .minimumScaleFactor(0.5)
      } else if isActive {
        Rectangle()
          .fill(TollColor.accent)
          .frame(width: 2, height: 28)
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: TollRadius.field, style: .continuous)
        .strokeBorder(TollColor.accent, lineWidth: 2)
        .opacity(isActive ? 1 : 0)
    }
    .frame(maxWidth: 60)
    .frame(height: 60)
    .animation(Motion.codeRing, value: code.count)
  }

  private func shake() {
    let step = Motion.Duration.movement / 5
    Task { @MainActor in
      if reduceMotion {
        withAnimation(.easeInOut(duration: step * 2)) { dimmed = true }
        try? await Task.sleep(for: .seconds(step * 2))
        code = ""
        withAnimation(.easeInOut(duration: step * 3)) { dimmed = false }
        return
      }
      for (index, x) in [6.0, -6.0, 6.0, -6.0, 0.0].enumerated() {
        withAnimation(.linear(duration: step)) { shakeOffset = x }
        try? await Task.sleep(for: .seconds(step))
        if index == 2 { code = "" }
      }
    }
  }
}
