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
  public private(set) var screenTime = ScreenTimeAuthorization.State.notDetermined
  public private(set) var location = LocationAccess.State.notDetermined
  public let config = TollConfig.defaults
  /// The App Store's localized price once it answers (D34).
  public private(set) var price = Copy.fallbackPrice
  /// The last command the coordinator refused, for the screen that sent it.
  public private(set) var lastError: CommandError?
  @ObservationIgnored let locationAccess = LocationAccess()
  @ObservationIgnored let coordinator = Coordinator.live()
  @ObservationIgnored private var started = false

  public init() {
    locationAccess.onChange = { [weak self] in self?.readPermissions() }
  }

  /// Called from `didFinishLaunching`, which also runs for a background relaunch by a region event:
  /// the place watch must be open before that event is delivered.
  public func start() {
    guard !started else { return }
    started = true
    #if DEBUG
      // Demo launches render screens; opening location would put a prompt over them.
      if DemoScenario.current != nil { return }
    #endif
    clearTollLeftovers()
    Task {
      await PlaceMonitor.shared.watch { [weak self] place, presence in
        await self?.send(presence.isInside ? .arrived : .left, [.presence(place, presence)])
      }
    }
    Task {
      await Purchase.watch { [weak self] purchased in await self?.setPurchased(purchased) }
    }
    Task { if let price = await Purchase.displayPrice() { self.price = price } }
    send(.launch, TrialClock().start.map { [.trialStart($0)] } ?? [])
    countApps()
    Task.detached(priority: .background) { TransitionLog().trim() }
  }

  public func foreground() {
    #if DEBUG
      // A demo launch shows a state it built; reading the store would replace it.
      if DemoScenario.current != nil { return }
    #endif
    readPermissions()
    send(.foreground)
    Task {
      setPurchased(await Purchase.isPurchased())
      // A region event can land while nothing was listening, such as before the first unlock after a
      // restart; the monitor's last word fills that in.
      for (place, presence) in await PlaceMonitor.shared.current()
      where state.presence[place]?.isInside != presence.isInside {
        send(presence.isInside ? .arrived : .left, [.presence(place, presence)])
      }
    }
  }

  /// Every change goes through here.
  @discardableResult
  func send(_ cause: ReconcileCause, _ commands: [Command] = []) -> CommandError? {
    let outcome = coordinator.wake(cause, commands)
    state = outcome.state
    lastError = outcome.error
    log = TransitionLog().read(limit: 200)
    let places = outcome.effects.places
    Task { await PlaceMonitor.shared.sync(places) }
    return outcome.error
  }

  /// Reads what the extensions wrote, without reconciling.
  func refresh() {
    #if DEBUG
      if DemoScenario.current != nil { return }
    #endif
    let latest = DuskStore().load()
    if latest != state { state = latest }
  }

  #if DEBUG
    func show(_ demo: DuskState) { state = demo }
  #endif

  // MARK: Permissions

  public func requestScreenTime() async {
    screenTime = await ScreenTimeAuthorization.request()
  }

  public func readPermissions() {
    screenTime = ScreenTimeAuthorization.state
    location = locationAccess.state
    if let mode = Self.locationMode(location), mode != state.location {
      send(.permission, [.location(mode)])
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
