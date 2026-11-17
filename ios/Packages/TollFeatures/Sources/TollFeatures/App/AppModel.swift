import Foundation
import Observation
import TollCore
import TollData
import TollScreenTime

/// The app's copy of the shared state, and every way the app changes it. Each change goes through
/// `Reconciler`, the same path the extensions take.
@MainActor
@Observable
public final class AppModel {
  public private(set) var state = SleepState()
  public private(set) var log: [Transition] = []
  public private(set) var screenTime = ScreenTimeAuthorization.State.notDetermined
  public private(set) var location = LocationAccess.State.notDetermined
  public let config = TollConfig.defaults
  @ObservationIgnored let locationAccess = LocationAccess()
  @ObservationIgnored private let reconciler = Reconciler()
  @ObservationIgnored private var started = false

  public init() {
    locationAccess.onChange = { [weak self] in self?.readPermissions() }
  }

  /// Called from `didFinishLaunching`, which also runs for a background relaunch by a region event:
  /// the home watch must be open before that event is delivered.
  public func start() {
    guard !started else { return }
    started = true
    #if DEBUG
      // Demo launches render screens; opening location would put a prompt over them.
      if DemoScenario.current != nil { return }
    #endif
    Task {
      await HomeRegion.shared.watch { [weak self] presence in await self?.update(presence) }
    }
    reconcile(.launch)
    Task.detached(priority: .background) { TransitionLog().trim() }
  }

  public func foreground() {
    readPermissions()
    reconcile(.foreground)
    Task {
      // A region event can land while nothing was listening, such as before the first unlock after a
      // restart; the monitor's last word fills that in.
      if let presence = await HomeRegion.shared.current(), presence.isHome != state.presence?.isHome
      {
        update(presence)
      }
    }
  }

  public func reconcile(_ cause: ReconcileCause, change: (inout SleepState) -> Void = { _ in }) {
    state = reconciler.run(cause, change: change)
    log = reconciler.log.read(limit: 200)
    Task { await syncRegion() }
  }

  /// Reads what the extensions wrote, without reconciling.
  func refresh() {
    let latest = reconciler.store.load()
    if latest != state { state = latest }
  }

  public func submit(_ edit: SleepSettings) {
    reconcile(.edit) { $0.submit(edit) }
  }

  func finishSetup() {
    reconcile(.edit) { $0.setupFinishedAt = Date() }
  }

  func update(_ presence: Presence) {
    reconcile(presence.isHome ? .arrived : .left) { $0.presence = presence }
  }

  public func requestScreenTime() async {
    screenTime = await ScreenTimeAuthorization.request()
  }

  public func requestLocation() {
    locationAccess.request()
  }

  public func readPermissions() {
    screenTime = ScreenTimeAuthorization.state
    location = locationAccess.state
    let check = Self.homeCheck(location) ?? state.homeCheck
    if check != state.homeCheck { reconcile(.permission) { $0.homeCheck = check } }
  }

  /// Region events reach a closed app only with Always and Precise (decisions D8, D10); anything less
  /// and the window alone decides. Not asked yet leaves it as it was.
  static func homeCheck(_ location: LocationAccess.State) -> HomeCheck? {
    switch location {
    case .always: .location
    case .whileUsing, .denied, .approximate: .windowOnly
    case .notDetermined: nil
    }
  }

  /// A home moved in an extension's reconcile (a held edit applied at window end) is picked up here.
  private func syncRegion() async {
    let wanted = state.settings.home
    if await HomeRegion.shared.watched() != wanted {
      await HomeRegion.shared.set(wanted)
    }
  }
}
