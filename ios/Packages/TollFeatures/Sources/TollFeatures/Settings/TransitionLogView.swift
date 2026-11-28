import SwiftUI
import TollCore
import TollUI

/// The transition log (B-6), newest first. Kept until the founders remove it (spec §2). Drawn with
/// the app's own page and cards, never the system list's white rows (D95, #162).
struct TransitionLogView: View {
  let model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ScreenTitle(Copy.Settings.log, kind: .pushed)
        Card {
          SettingsRow(Copy.Settings.version) {
            Text(AppLinks.version).tollType(.detail, TollColor.label2)
          }
          // For the founders' replays and data science (#51, #87): the night records as a file.
          ShareLink(item: NightLog().url) {
            SettingsRow(Copy.Settings.shareNights) {
              Image(symbol: .share).unredacted()
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TollColor.label3)
                .accessibilityHidden(true)
            }
          }
          .buttonStyle(.plain)
        }
        .padding(.top, TollSpacing.titleToContent)
        lines.padding(.top, 12)
      }
      .tollGutter()
      .padding(.bottom, 32)
    }
    .background(TollColor.bg)
    .tollPushed(Copy.Settings.log)
  }

  /// Lazily, so a long log opens at once; one card, its lines split by hairlines.
  @ViewBuilder private var lines: some View {
    if model.log.isEmpty {
      NoteCard(Copy.Settings.logEmpty)
    } else {
      LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(Array(model.log.enumerated()), id: \.offset) { index, line in
          if index > 0 { Hairline() }
          Text(Copy.Settings.line(line))
            .tollType(.detail, TollColor.label)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
        }
      }
      .padding(.horizontal, TollSpacing.cardPadding)
      .tollSurface()
    }
  }
}
