#if os(iOS)
  import ManagedSettings

  extension ManagedSettingsStore.Name {
    /// One named store holds every block's shield (spec §11.1). Computed because `Name` is not Sendable.
    public static var blocks: Self { Self("blocks") }
  }
#endif
