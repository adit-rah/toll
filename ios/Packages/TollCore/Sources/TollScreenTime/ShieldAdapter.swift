#if os(iOS)
  @preconcurrency import FamilyControls
  import Foundation
  @preconcurrency import ManagedSettings
  import TollCore

  /// ShieldPort on ManagedSettings: the union of every active block's apps, sites and categories
  /// (D29), in one store, so clearing it lifts every block's shield at once: nothing on, or a pause
  /// open (D67).
  public struct ShieldAdapter: ShieldPort {
    public init() {}

    public func apply(_ plan: ShieldPlan) {
      let store = ManagedSettingsStore(named: .sleep)
      guard !plan.isOff else {
        store.clearAllSettings()
        return
      }
      var apps = Set<ApplicationToken>()
      var sites = Set<WebDomainToken>()
      var categories = Set<ActivityCategoryToken>()
      for data in plan.selections {
        let selection = Blocklist.selection(from: data)
        apps.formUnion(selection.applicationTokens)
        sites.formUnion(selection.webDomainTokens)
        categories.formUnion(selection.categoryTokens)
      }
      store.shield.applications = apps.isEmpty ? nil : apps
      store.shield.webDomains = sites.isEmpty ? nil : sites
      store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
      store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
    }
  }

  /// A block's apps, stored as the picker's own encoding; only this glue reads it.
  public enum Blocklist {
    /// iOS refuses a shield of more than 50 apps and sites by name (spec §5).
    public static let platformMax = 50

    public static func selection(from data: Data?) -> FamilyActivitySelection {
      data.flatMap { try? JSONDecoder().decode(FamilyActivitySelection.self, from: $0) }
        ?? FamilyActivitySelection()
    }

    public static func encode(_ selection: FamilyActivitySelection) -> Data? {
      try? JSONEncoder().encode(selection)
    }

    /// Apps and sites named one by one: what counts towards the limit (D29).
    public static func items(_ selection: FamilyActivitySelection) -> Int {
      selection.applicationTokens.count + selection.webDomainTokens.count
    }

    public static func isEmpty(_ selection: FamilyActivitySelection) -> Bool {
      items(selection) == 0 && selection.categoryTokens.isEmpty
    }

    /// Fills in a block's counts from its selection: the domain cannot open it.
    public static func counted(_ block: Block) -> Block {
      let selection = selection(from: block.apps)
      var block = block
      block.appCount = items(selection)
      block.categoryCount = selection.categoryTokens.count
      return block
    }

    /// The blocks whose selection names this app, directly or by its category.
    public static func blocks(
      _ blocks: [Block], containing app: ApplicationToken?, category: ActivityCategoryToken?
    ) -> [Block] {
      blocks.filter { block in
        let selection = selection(from: block.apps)
        if let app, selection.applicationTokens.contains(app) { return true }
        if let category, selection.categoryTokens.contains(category) { return true }
        return false
      }
    }
  }
#endif
