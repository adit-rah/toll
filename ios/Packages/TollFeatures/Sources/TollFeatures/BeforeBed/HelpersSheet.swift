import SwiftUI
import TollCore
import TollData
import TollUI

/// Before bed (D80): three small things for the minutes between the lock and bed, a sheet over
/// Tonight from its quiet capsule or its one card. The choices, then the one picked; each ends with
/// the phone down. Nothing typed, timed or saved, and no visual pacer: the tone does the pacing.
/// Every page is the same height, so swapping pages never moves the sheet.
struct HelpersSheet: View {
  let model: AppModel
  let close: () -> Void
  @State private var page: Helper?
  /// The tone, observed so its page follows it; demo renders stand in a time without a sound.
  private let tone = BreathTone.shared
  private let demoUntil: Date?
  @Environment(\.dynamicTypeSize) private var typeSize
  static let height: CGFloat = 520

  /// Reopened while the tone plays, it opens on the tone.
  init(
    model: AppModel, page: Helper? = nil, demoUntil: Date? = nil, close: @escaping () -> Void
  ) {
    self.model = model
    self.close = close
    self.demoUntil = demoUntil
    _page = State(initialValue: page ?? (BreathTone.shared.playing ? .breathe : nil))
  }

  var body: some View {
    switch page {
    case nil: choices
    case .list:
      HelperPage(helper: .list, title: Copy.Helpers.listTitle, lines: [Copy.Helpers.listBody]) {
        finish
      }
    case .breathe:
      HelperPage(
        helper: .breathe, title: Copy.Helpers.breathe(minutes: model.breathMinutes),
        lines: [Copy.Helpers.breatheBody]
      ) {
        if let until = demoUntil ?? tone.endsAt {
          PrimaryButton(tone: .neutral, action: { model.stopBreath() }) {
            HStack(spacing: 8) {
              Image(symbol: .stopTone).unredacted().accessibilityHidden(true)
              Text(Copy.Helpers.stopTone)
            }
          }
          // The quiet link's height, so Stop sits where Done lands when the tone ends.
          Footnote(
            Copy.Helpers.toneUntil(Copy.time(until)), symbol: .tone, alignment: .center
          )
          .frame(maxWidth: .infinity, minHeight: TollSpacing.minTapTarget)
        } else {
          finish
        }
      }
    case .words:
      HelperPage(
        helper: .words, title: Copy.Helpers.words,
        lines: [Copy.Helpers.wordsBody, Copy.Helpers.wordsEnd]
      ) {
        finish
      }
    }
  }

  /// Each choice a row with its own glyph, so the three read apart without the words.
  private var choices: some View {
    SheetPage(height: Self.height, overhang: 16) {
      SheetTitle(Copy.Helpers.sheetTitle)
      SheetBody(Copy.Helpers.sheetBody)
      VStack(spacing: 0) {
        choice(.list, Copy.Helpers.list, detail: Copy.Helpers.listDetail)
        Hairline()
        choice(
          .breathe, Copy.Helpers.breathe(minutes: model.breathMinutes),
          detail: Copy.Helpers.breatheDetail)
        Hairline()
        choice(.words, Copy.Helpers.words, detail: Copy.Helpers.wordsDetail)
      }
      .padding(.top, 20)
    } actions: {
      QuietButton(Copy.Home.notNow, action: close).frame(maxWidth: .infinity)
    }
  }

  private func choice(_ helper: Helper, _ title: String, detail: String) -> some View {
    Button {
      model.openHelper(helper)
      page = helper
    } label: {
      // Side by side with the chevron centred; at accessibility sizes the tile above the words, and
      // no chevron left alone on a line.
      let layout =
        typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: TollSpacing.rowGap))
        : AnyLayout(HStackLayout(spacing: TollSpacing.rowGap))
      layout {
        IconTile(.helper(helper), accent: false)
        RowText(title: title, detail: detail)
        if !typeSize.isAccessibilitySize {
          Spacer(minLength: 0)
          Chevron()
        }
      }
      .padding(.vertical, 8)
      .frame(minHeight: 60)
      .contentShape(Rectangle())
    }
    .buttonStyle(.tollPressable)
    .accessibilityElement(children: .combine)
  }

  /// "Done" closes the sheet; "Something else" goes back to the three.
  @ViewBuilder private var finish: some View {
    PrimaryButton(Copy.Helpers.done, action: close)
    QuietButton(Copy.Helpers.somethingElse) { page = nil }.frame(maxWidth: .infinity)
  }
}

/// One helper's page: its glyph, a title and its words, then its actions.
private struct HelperPage<Actions: View>: View {
  let helper: Helper
  let title: String
  let lines: [String]
  @ViewBuilder let actions: Actions

  var body: some View {
    SheetPage(height: HelpersSheet.height, overhang: 16) {
      IconTile(.helper(helper), size: .sheet, accent: false)
      SheetTitle(title).padding(.top, 18)
      ForEach(lines, id: \.self) { SheetBody($0) }
    } actions: {
      actions
    }
  }
}
