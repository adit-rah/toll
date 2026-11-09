#if os(iOS)
  import ManagedSettings

  extension ManagedSettingsStore.Name {
    /// One named store holds every block's shield (spec §11.1).
    public static let blocks = Self("blocks")
  }
#endif
