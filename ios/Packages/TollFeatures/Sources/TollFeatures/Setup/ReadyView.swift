@preconcurrency import FamilyControls
import SwiftUI
import TollCore
import TollScreenTime
import TollUI

/// Ready (D68, #76, #144): tonight as pictures. A tick before the eyebrow, when apps lock, tonight
/// drawn lock · sleep · open, the same three as lines, then one short line of the rest: where it
/// runs (anywhere until home is set), the apps' count and the week's pauses. Short enough to read
/// whole at the default size; it scrolls at accessibility sizes, where the free nights' footnote
/// scrolls with it and only Done stays pinned (#168). No back button: onboarding is done.
struct ReadyView: View {
  let model: SetupModel
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    SetupPage(
      title: line, eyebrow: Copy.Setup.readyEyebrow, eyebrowSymbol: .done
    ) {
      let draft = model.draft
      if let night = NightPicture(
        draft.schedule, gap: draft.before.start, after: draft.after.start, now: Date(),
        calendar: .current)
      {
        NightPictureView(picture: night).padding(.top, 20)
        // The night in three lines, in the picture's order: lock, sleep, open.
        Card {
          CardRow(
            Copy.Fit.lockAt(night.lockTime ?? night.start),
            detail: Copy.Fit.beforeSleep(draft.before.start), size: .list
          ) {
            IconTile(.blocked, accent: false)
          }
          CardRow(Copy.Gap.sleepSpan(night.start, night.end), size: .list) {
            IconTile(.sleep)
          }
          CardRow(
            Copy.Fit.openAt(night.openTime ?? night.end),
            detail: Copy.Fit.afterWaking(draft.after.start), size: .list
          ) {
            IconTile(.open, accent: false)
          }
        }
        .padding(.top, 16)
      }
      // The rest, one short line of what else tonight holds.
      VStack(alignment: .leading, spacing: 10) {
        AdaptiveStack(spacing: 14) {
          fact(.anywhere, Copy.Setup.anywhere)
          fact(.apps, apps.isEmpty ? Copy.Setup.blocked : apps)
        }
        // The week's pauses as dots, as everywhere they're shown (design §2.6), on a line of
        // their own so the words beside them don't wrap.
        HStack(spacing: 10) {
          fact(.unlock, Copy.Setup.unlocks(unlocks, minutes: model.app.config.door.minutes))
          Pips(
            filled: unlocks, total: unlocks,
            spoken: Copy.Setup.unlocks(unlocks, minutes: model.app.config.door.minutes)
          )
          .accessibilityHidden(true)
        }
      }
      .padding(.vertical, 12)
      .padding(.horizontal, TollSpacing.cardPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .tollSurface()
      .accessibilityElement(children: .combine)
      .padding(.top, 12)
      if typeSize.isAccessibilitySize {
        trial.padding(.top, 24)
      }
    } actions: {
      if !typeSize.isAccessibilitySize {
        trial.padding(.bottom, TollSpacing.aboveButton)
      }
      PrimaryButton(Copy.Setup.done) { model.finish() }
    }
    .navigationBarBackButtonHidden()
  }

  /// The free nights as segments, none used yet (#77), over the words; on a fresh start, tonight's
  /// ringed as on the pill: tonight is the first (#66).
  @ViewBuilder private var trial: some View {
    if let footnote {
      VStack(spacing: 8) {
        if model.offer(now: Date()).isFree {
          FreeNights(
            used: 0, total: model.app.config.trial.nights, tonight: freshStart ? 0 : nil,
            spoken: footnote
          )
          .accessibilityHidden(true)
        }
        Footnote(footnote, alignment: .center)
          .padding(.horizontal, 12)
      }
      .frame(maxWidth: .infinity)
    }
  }

  private var unlocks: Int { model.app.config.unlocks.max }

  private var freshStart: Bool {
    if case .fresh = model.offer(now: Date()) { return true }
    return false
  }

  /// "2 categories · 2 apps"; the simulator has no tokens to count.
  private var apps: String {
    Copy.Setup.blockedCount(
      categories: model.selection.categoryTokens.count, apps: Blocklist.items(model.selection))
  }

  private func fact(_ symbol: TollSymbol, _ text: String) -> some View {
    HStack(spacing: 6) {
      Image(symbol: symbol).unredacted()
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(TollColor.label2)
        .accessibilityHidden(true)
      Text(text).tollType(.detail, TollColor.label)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

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
