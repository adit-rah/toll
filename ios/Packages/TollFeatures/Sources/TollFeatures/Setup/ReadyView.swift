@preconcurrency import FamilyControls
@preconcurrency import ManagedSettings
import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// Ready (D68, #76): tonight as pictures. A tick before the eyebrow, when apps lock, tonight's night
/// as moon bed – wake sun with the gap before the moon (D76), how long before bed, then where it runs
/// (anywhere until home is set), the apps with their count and icons, and the unlocks as dots. No
/// back button: onboarding is done.
struct ReadyView: View {
  let model: SetupModel

  var body: some View {
    SetupPage(
      step: nil, title: line, eyebrow: Copy.Setup.readyEyebrow, eyebrowSymbol: .done
    ) {
      if let night = NightPicture(model.schedule, gap: model.gap, now: Date(), calendar: .current) {
        NightPictureView(picture: night).padding(.top, 24)
      }
      Card {
        CardRow(
          Copy.Gap.beforeBed(model.gap),
          detail: Copy.Gap.readyDetail(cap: model.app.config.gap.cap)
        ) {
          IconTile(.beforeBed, accent: false)
        }
        CardRow(Copy.Setup.anywhere, detail: Copy.Setup.anywhereUntilHome) {
          IconTile(.anywhere, accent: false)
        }
        CardRow(
          Copy.Setup.blocked,
          detail: Copy.Setup.blockedCount(
            categories: model.selection.categoryTokens.count,
            apps: Blocklist.items(model.selection))
        ) {
          IconTile(.apps, accent: false)
        } trailing: {
          AppIcons(tokens: Array(model.selection.applicationTokens.prefix(3)))
        }
        CardRow(
          Copy.Setup.unlocks(unlocks),
          detail: Copy.Setup.unlocksDetail(minutes: model.app.config.door.minutes)
        ) {
          IconTile(.unlock, accent: false)
        } trailing: {
          Pips(filled: unlocks, total: unlocks, spoken: Copy.Setup.unlocks(unlocks))
        }
      }
      .padding(.top, 24)
    } actions: {
      if let footnote {
        // The free nights as segments, none used yet (#77), over the words.
        if model.offer(now: Date()).isFree {
          FreeNights(used: 0, total: model.app.config.trial.nights, spoken: footnote)
            .accessibilityHidden(true)
            .padding(.bottom, 8)
        }
        Footnote(footnote, alignment: .center)
          .padding(.horizontal, 12)
          .padding(.bottom, TollSpacing.aboveButton)
      }
      PrimaryButton(Copy.Setup.done) { model.finish() }
    }
    .navigationBarBackButtonHidden()
  }

  private var unlocks: Int { model.app.config.unlocks.max }

  /// From the stored trial start, so a reinstall or a new phone isn't promised more (#46, D78).
  private var footnote: String? {
    let day = { (date: Date) in date.formatted(.dateTime.month(.abbreviated).day()) }
    switch model.offer(now: Date()) {
    case .fresh(let end?), .running(let end):
      return Copy.Setup.freeUntil(day(end), price: model.app.price)
    case .used(let ended): return Copy.Setup.freeNightsEnded(day(ended), price: model.app.price)
    case .fresh(nil), .purchased: return nil
    }
  }

  private var line: String {
    let now = Date()
    let lock = model.lockSchedule
    if let night = lock.occurrence(containing: now, calendar: .current) {
      return Copy.Setup.readyNow(Copy.time(night.end))
    }
    let start = lock.nextStart(after: now, calendar: .current) ?? now
    return Copy.Setup.readyLine(Copy.time(start))
  }
}

/// Up to three of the chosen apps' own icons, from the system (`Label(token)`); the app never knows
/// which apps they are (D41). None in the simulator, which has no tokens.
private struct AppIcons: View {
  let tokens: [ApplicationToken]

  var body: some View {
    HStack(spacing: 4) {
      ForEach(tokens, id: \.self) { token in
        Label(token).labelStyle(.iconOnly).frame(width: 24, height: 24)
      }
    }
    .accessibilityHidden(true)
  }
}
