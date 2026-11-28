#if DEBUG
  import Foundation
  import TollCore

  /// States no scenario showed (#129, #141): a pause used past its regret time, Tonight with the
  /// wait running and its sheet swiped away, a held change to "Only when I'm home", the night locked
  /// with home not set, Your sleep after the free nights, Settings with Screen Time off and its
  /// activity log, and Welcome's other offers.
  extension DemoScenario {
    /// Locked like `home-blocked`, for the states built on it.
    var blockedToo: Bool {
      [.homePauseWaiting, .homeHeldHome, .homeBlockedAnywhere].contains(self)
    }

    /// Welcome's offer from a trial start kept in the Keychain (P-4): days before now.
    var trialStartedDaysAgo: Int? {
      switch self {
      case .welcomeRunning: 3
      case .welcomeUsed: 30
      default: nil
      }
    }
  }

  extension DemoFixture {
    /// The night is on and "Use anywhere" was chosen during it: the change waits for its end (B-3).
    mutating func polish(_ scenario: DemoScenario) {
      if scenario == .homeHeldHome, var night = state.sleepBlock {
        night.place = nil
        state.pending[night.id] = .save(night)
      }
      // Study switched off (#161): nothing of it is on, whatever its hours say.
      if [.blocksOff, .blockEditOff].contains(scenario),
        let study = state.blocks.firstIndex(where: { $0.id == BlockID("study") })
      {
        state.blocks[study].isOn = false
        state.runtime.active[BlockID("study")] = nil
      }
    }
  }
#endif
