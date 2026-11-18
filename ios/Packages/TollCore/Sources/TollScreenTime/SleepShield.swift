#if os(iOS)
  @preconcurrency import FamilyControls
  import Foundation
  @preconcurrency import ManagedSettings

  /// The block itself: the blocklist's apps, sites and categories (decisions D27). The door's app, if
  /// one is open, is left out for its minutes (D-2).
  public enum SleepShield {
    public static func apply(on: Bool, blocked: Data?, doorApp: Data? = nil) {
      let store = ManagedSettingsStore(named: .sleep)
      guard on else {
        store.clearAllSettings()
        return
      }
      let list = Blocklist.selection(from: blocked)
      let door = DoorApp.token(from: doorApp)
      var apps = list.applicationTokens
      if let door { apps.remove(door) }
      store.shield.applications = apps.isEmpty ? nil : apps
      store.shield.webDomains = list.webDomainTokens.isEmpty ? nil : list.webDomainTokens
      let categories = list.categoryTokens
      store.shield.applicationCategories =
        categories.isEmpty ? nil : .specific(categories, except: door.map { [$0] } ?? [])
      store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
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

  /// The blocklist is stored as the picker's own encoding; only this glue reads it.
  public enum Blocklist {
    /// iOS refuses a shield of more than 50 individual apps and sites (spec §5). Categories do not
    /// count towards it.
    public static let maxItems = 50

    public static func selection(from data: Data?) -> FamilyActivitySelection {
      data.flatMap { try? JSONDecoder().decode(FamilyActivitySelection.self, from: $0) }
        ?? FamilyActivitySelection()
    }

    public static func encode(_ selection: FamilyActivitySelection) -> Data? {
      try? JSONEncoder().encode(selection)
    }

    public static func items(_ selection: FamilyActivitySelection) -> Int {
      selection.applicationTokens.count + selection.webDomainTokens.count
    }

    public static func isEmpty(_ selection: FamilyActivitySelection) -> Bool {
      items(selection) == 0 && selection.categoryTokens.isEmpty
    }

    public static func fits(_ selection: FamilyActivitySelection) -> Bool {
      items(selection) <= maxItems
    }
  }
#endif
