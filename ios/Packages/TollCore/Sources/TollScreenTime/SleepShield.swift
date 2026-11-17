#if os(iOS)
  @preconcurrency import FamilyControls
  import Foundation
  @preconcurrency import ManagedSettings

  /// The block itself: every category shielded, the keep-open list as the exceptions (spec §5). Apps
  /// are never listed one by one, so the 50-token ceiling never applies to the block.
  public enum SleepShield {
    /// `doorApp` is the app the door has open, if any (D-2): one more exception for its minutes.
    public static func apply(on: Bool, keepOpen: Data?, doorApp: Data? = nil) {
      let store = ManagedSettingsStore(named: .sleep)
      guard on else {
        store.clearAllSettings()
        return
      }
      let exceptions = KeepOpen.selection(from: keepOpen)
      var apps = exceptions.applicationTokens
      if let door = DoorApp.token(from: doorApp) { apps.insert(door) }
      store.shield.applicationCategories = .all(except: apps)
      store.shield.webDomainCategories = .all(except: exceptions.webDomainTokens)
    }
  }

  /// The door's one app, stored as its encoded token.
  public enum DoorApp {
    public static func token(from data: Data?) -> ApplicationToken? {
      data.flatMap { try? JSONDecoder().decode(ApplicationToken.self, from: $0) }
    }

    public static func encode(_ token: ApplicationToken) -> Data? {
      try? JSONEncoder().encode(token)
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
