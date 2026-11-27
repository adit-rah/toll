@preconcurrency import FamilyControls
import Foundation
import Observation
import TollCore
import TollData
import TollScreenTime

/// Onboarding's draft (D68, #144): the shortest path to a first locked night, fitted to the
/// person's sleep. Fit Dusk to your sleep (Health or not), your sleep, the time around it, Screen
/// Time, the apps, then Ready; home comes later, from Tonight or Settings (`SetHomeModel`). Nothing
/// reaches the shared state until Ready is done, so leaving halfway arms nothing.
@MainActor
@Observable
final class SetupModel {
  enum Step: Hashable, CaseIterable {
    case fit, sleep, around, screenTime, blocklist, ready

    /// The progress bar counts the five questions; Ready is not one.
    var number: Int? {
      switch self {
      case .fit: 1
      case .sleep: 2
      case .around: 3
      case .screenTime: 4
      case .blocklist: 5
      case .ready: nil
      }
    }

    static let questions = 5
  }

  let app: AppModel
  var path: [Step]
  let draft: FitDraft
  var selection = FamilyActivitySelection()
  /// Welcome's "Buy it now": waiting for the App Store sheet.
  var buying = false

  init(app: AppModel, path: [Step] = [], draft: FitDraft? = nil) {
    self.app = app
    self.path = path
    self.draft = draft ?? .fresh(app.config)
  }

  /// The lock's hours, which Ready names: sleep with tonight's buffers around it.
  var lockSchedule: WeeklySchedule {
    draft.schedule.locking(before: draft.before.start, after: draft.after.start)
  }

  /// The trial's start from the Keychain: a reinstall keeps it (P-4).
  var trialStart = TrialClock().start

  /// What Welcome and Ready can promise this phone (#46).
  func offer(now: Date, calendar: Calendar = .current) -> Trial.Offer {
    Trial.offer(
      start: trialStart, purchased: app.state.trial.purchased, now: now, sleep: draft.schedule,
      calendar: calendar, config: app.config)
  }

  func go(_ step: Step) { path.append(step) }

  // MARK: Welcome

  /// "Buy it now": the App Store's sheet; bought or not, setup goes on (#144).
  func buyNow() async {
    buying = true
    _ = await app.buy()
    buying = false
    go(.fit)
  }

  // MARK: Fit Dusk to your sleep

  /// "Use Apple Health": iOS's sheet, then the usual times if there are enough nights; otherwise
  /// the same step asks.
  func useHealth() async {
    draft.reading = true
    draft.health = true
    draft.found(await app.readSleep())
    draft.reading = false
    go(.sleep)
  }

  func setMyself() {
    draft.health = false
    draft.found(nil)
    go(.sleep)
  }

  // MARK: Screen Time

  var screenTimeReady: Bool { app.screenTime == .approved }

  /// Screen Time alone (D68): location is asked only when home is set, after the first night.
  func allow() async {
    if app.screenTime != .approved { await app.requestScreenTime() }
  }

  // MARK: Blocklist and finish

  /// At least one thing to block, and no more than the limit across blocks (D29).
  var blocklistReady: Bool {
    !Blocklist.isEmpty(selection) && Blocklist.items(selection) <= app.config.blocks.maxApps
  }

  func blocklistChosen() { go(.ready) }

  /// The Sleep block with no place: until home is set it runs on its hours wherever the phone is
  /// (D68, the engine's D37 path). Built here, sent once at the end.
  var sleepBlock: Block {
    Block(
      name: Copy.Setup.nightName, kind: .sleep, place: nil, schedule: draft.schedule,
      apps: Blocklist.encode(selection))
  }

  func finish() { app.finishSetup(sleep: sleepBlock, home: nil, fit: draft.fit) }
}
