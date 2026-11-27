@preconcurrency import FamilyControls
import Foundation
import Observation
import TollCore
import TollData
import TollScreenTime

/// The presentation layer's one door into the app (docs/architecture.md): it sends commands through
/// the coordinator, the same path the extensions take, and publishes the resulting state for screens to
/// read. Screens never touch adapters or rules.
@MainActor
@Observable
public final class AppModel {
  public private(set) var state = DuskState()
  public private(set) var log: [Transition] = []
  /// Every recorded night (D62), so Your sleep's counts outlive the log's trimming (#103).
  public internal(set) var history: [PastNight] = []
  public private(set) var screenTime = ScreenTimeAuthorization.State.notDetermined
  public private(set) var location = LocationAccess.State.notDetermined
  /// iOS's answer for the heads-up (D68); nil until read, and nothing is scheduled or offered before.
  public internal(set) var notifications: NotificationPermission?
  public let config = TollConfig.defaults
  /// The App Store's localized price once it answers (D34).
  public private(set) var price = Copy.fallbackPrice
  /// The last command the coordinator refused, for the screen that sent it.
  public private(set) var lastError: CommandError?
  @ObservationIgnored let locationAccess = LocationAccess()
  @ObservationIgnored let coordinator = Coordinator.live()
  @ObservationIgnored private var started = false
  /// The place watch is open (`watchPlaces`).
  @ObservationIgnored private var watchingPlaces = false
  /// What was last handed to iOS, so only a change reschedules; nil reschedules on the next sync.
  @ObservationIgnored var scheduledHeadsUps: [HeadsUp]?
  /// The night log's last write, so the next waits for it.
  @ObservationIgnored private var recording: Task<Void, Never>?
  /// The one-time flow due at the last foreground (`Flows`): "Fit Dusk to your sleep" (#144).
  public internal(set) var dueFlow: String?
  /// The state file is a newer build's, which this one only reads (`DuskState.minReader`).
  public private(set) var readOnly = false

  public init() {
    // Read now, so Home's first frame doesn't claim Screen Time is off (#45).
    screenTime = ScreenTimeAuthorization.state
    locationAccess.onChange = { [weak self] in self?.readPermissions() }
  }

  /// Called from `didFinishLaunching`, which also runs for a background relaunch by a region event:
  /// the place watch must be open before that event is delivered.
  public func start() {
    guard !started else { return }
    started = true
    #if DEBUG
      // Demo launches render screens; opening location would put a prompt over them. Their state is
      // in place before the first frame, so a sheet or pushed screen never shows an empty app (#73).
      if let demo = DemoScenario.current {
        ScreenTimeAuthorization.simulated = demo.screenTime
        LocationAccess.simulated = demo.location
        NotificationAdapter.simulated = demo.notifications
        screenTime = ScreenTimeAuthorization.state
        location = locationAccess.state
        notifications = demo.notifications
        if demo.isHome {
          let fixture = DemoFixture(scenario: demo, now: DemoClock.now(for: demo))
          state = fixture.state
          log = fixture.log.reversed()
        }
        return
      }
    #endif
    clearTollLeftovers()
    watchPlaces()
    Task {
      await Purchase.watch { [weak self] purchased in await self?.setPurchased(purchased) }
    }
    Task { if let price = await Purchase.displayPrice() { self.price = price } }
    send(.launch, TrialClock().settle().map { [.trialStart($0)] } ?? [])
    countApps()
  }

  public func foreground() {
    #if DEBUG
      // A demo launch shows a state it built; reading the store would replace it.
      if DemoScenario.current != nil { return }
    #endif
    // Opening the app always hands iOS a fresh plan (#104).
    scheduledHeadsUps = nil
    readPermissions()
    // iCloud Keychain may have brought an earlier start from another phone since (D78).
    send(.foreground, TrialClock().settle().map { [.trialStart($0)] } ?? [])
    recordNights()
    dueFlow = Flows.due(state, now: Date(), calendar: .current, config: config)?.id
    Task {
      setPurchased(await Purchase.isPurchased())
      guard watchingPlaces else { return }
      // A region event can land while nothing was listening, such as before the first unlock after a
      // restart; the monitor's last word fills that in.
      for (place, presence) in await PlaceMonitor.shared.current()
      where state.presence[place]?.isInside != presence.isInside {
        send(presence.isInside ? .arrived : .left, [.presence(place, presence)])
      }
    }
  }

  /// One record per ended Sleep night into the night log, so the nights outlive the transition
  /// log's trimming (#51), then the trim, never before (#140); then the person's model state moves
  /// on by those nights, or is rebuilt for a new artifact. Off the main thread, one run at a time.
  func recordNights() {
    history = NightLog().past(calendar: .current)
    let state = state
    let config = config
    let previous = recording
    recording = Task.detached(priority: .utility) { [weak self] in
      await previous?.value
      NightKeeper().keep(
        state, model: ModelStore.stamp, now: Date(), calendar: .current, config: config)
      ModelStore().refresh()
      let past = NightLog().past(calendar: .current)
      await self?.show(history: past)
      // Health's sleep for the nights just recorded, once a watch has synced it (#144).
      await self?.correctNightsFromHealth()
    }
  }

  private func show(history: [PastNight]) {
    self.history = history
  }

  /// Every change goes through here.
  @discardableResult
  func send(_ cause: ReconcileCause, _ commands: [Command] = []) -> CommandError? {
    #if DEBUG
      // A demo shows a state it built; reconciling against the real store would replace it.
      if DemoScenario.current != nil { return nil }
    #endif
    let outcome = coordinator.wake(cause, commands)
    // Unread: the file couldn't be opened, so nothing ran; what's on screen stays.
    guard outcome.access != nil else { return nil }
    readOnly = outcome.access == .readOnly
    state = outcome.state
    lastError = outcome.error
    // The whole log: a week of Sleep nights must survive many windows and taps (#44).
    log = TransitionLog().read()
    if watchingPlaces {
      let places = outcome.effects.places
      Task { await PlaceMonitor.shared.sync(places) }
    }
    // Every change that could move the night passes here: hours, a held edit applying, entitlement.
    syncHeadsUp()
    return outcome.error
  }

  /// Reads what the extensions wrote, without reconciling.
  func refresh() {
    #if DEBUG
      if DemoScenario.current != nil { return }
    #endif
    guard let latest = DuskStore().loadIfReadable() else { return }
    guard latest != state else { return }
    state = latest
    // The monitor applies a held edit when the night ends; the heads-up follows the new hours.
    syncHeadsUp()
  }

  // MARK: Permissions

  public func requestScreenTime() async {
    screenTime = await ScreenTimeAuthorization.request()
  }

  public func readPermissions() {
    screenTime = ScreenTimeAuthorization.state
    // Recorded in the shared state, so every log line after it, the monitor's too, says whether
    // anything could block (#60). Before setup there's nothing to record.
    let allowed = screenTime == .approved
    if state.setupFinishedAt != nil, state.screenTimeAllowed != allowed {
      send(.permission, [.screenTime(allowed)])
    }
    location = locationAccess.state
    watchPlaces()
    if let mode = Self.locationMode(location), mode != state.location {
      send(.permission, [.location(mode)])
    }
    Task { await readNotifications() }
  }

  /// Opens the place watch once the person has given Always, the only grant that lets region events
  /// reach a closed app (D10). Its location session and monitor, opened earlier, make iOS ask for
  /// location at launch, before Set home has said why. Below Always, blocks run on their hours (D37).
  func watchPlaces() {
    #if DEBUG
      // A demo's Always is simulated; the real session would put iOS's prompt over the screen.
      if DemoScenario.current != nil { return }
    #endif
    guard !watchingPlaces, locationAccess.state == .always else { return }
    watchingPlaces = true
    Task {
      await PlaceMonitor.shared.watch { [weak self] place, presence in
        await self?.send(presence.isInside ? .arrived : .left, [.presence(place, presence)])
      }
    }
  }

  /// Region events reach a closed app only with Always and Precise (decisions D10); anything less and
  /// every block runs on its hours alone (D37). Not asked yet leaves it as it was.
  static func locationMode(_ location: LocationAccess.State) -> LocationMode? {
    switch location {
    case .always: .places
    case .whileUsing, .denied, .approximate: .scheduleOnly
    case .notDetermined: nil
    }
  }

  // MARK: Upgrades

  /// Decisions D28: an upgrade from Toll must not keep Toll's shields, schedules or data.
  private func clearTollLeftovers() {
    TollLeftovers.clear()
    Keychain().removeTollItems()
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    for folder in support {
      for name in ["toll.sqlite", "toll.sqlite-wal", "toll.sqlite-shm"] {
        try? FileManager.default.removeItem(at: folder.appending(path: name))
      }
    }
  }

  /// A block migrated from step 2 has no app counts: only the Screen Time adapter can open its apps.
  private func countApps() {
    let uncounted = state.blocks.filter {
      $0.apps != nil && $0.appCount == 0 && $0.categoryCount == 0
    }
    guard !uncounted.isEmpty else { return }
    send(.edit, uncounted.map { .saveBlock(Blocklist.counted($0)) })
  }
}
