#if os(iOS)
  @preconcurrency import FamilyControls
  import Foundation
  @preconcurrency import ManagedSettings

  /// The block itself: every category shielded, the keep-open list as the exceptions (spec §5). Apps
  /// are never listed one by one, so the 50-token ceiling never applies to the block.
  public enum SleepShield {
    public static func apply(on: Bool, keepOpen: Data?) {
      let store = ManagedSettingsStore(named: .sleep)
      guard on else {
        store.clearAllSettings()
        return
      }
      let exceptions = KeepOpen.selection(from: keepOpen)
      store.shield.applicationCategories = .all(except: exceptions.applicationTokens)
      store.shield.webDomainCategories = .all(except: exceptions.webDomainTokens)
    }
  }

  /// The keep-open list is stored as the picker's own encoding; only this glue reads it.
  public enum KeepOpen {
    public static func selection(from data: Data?) -> FamilyActivitySelection {
      data.flatMap { try? JSONDecoder().decode(FamilyActivitySelection.self, from: $0) }
        ?? FamilyActivitySelection()
    }

    public static func encode(_ selection: FamilyActivitySelection) -> Data? {
      try? JSONEncoder().encode(selection)
    }
  }
#endif
