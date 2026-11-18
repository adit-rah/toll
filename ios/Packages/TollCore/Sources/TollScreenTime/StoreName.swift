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
    /// One door use: starts when the wait ends, lasts the platform minimum (spec §5, D-2).
    public static var door: Self { Self("sleep.door") }
  }

  extension DeviceActivityEvent.Name {
    /// The door app's minutes of use are spent.
    public static var doorUse: Self { Self("sleep.door.use") }
  }
#endif
