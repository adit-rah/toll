#if os(iOS)
  @preconcurrency import DeviceActivity
  @preconcurrency import ManagedSettings

  extension ManagedSettingsStore.Name {
    /// The one store the block lives in. Computed because `Name` is not Sendable.
    public static var sleep: Self { Self("sleep") }
  }

  extension DeviceActivityName {
    /// The sleep window, repeating nightly (spec §6).
    public static var sleepWindow: Self { Self("sleep.window") }
    /// A short interval just after the window ends: a second wake, so a missed end callback cannot
    /// leave the block on in the morning (B-4).
    public static var sleepSweep: Self { Self("sleep.sweep") }
  }
#endif
