import Foundation
import TollCore

/// Every service a screen may need, injected through `init` (spec §11.1). `.live` for the app, `.preview`
/// for SwiftUI previews and `.test` for anything that must not touch the phone's real state.
public struct Dependencies: Sendable {
  public var clock: any TollClock
  public var store: LocalStore
  public var api: APIClient
  public var keychain: Keychain
  public var sync: SyncEngine
  public var gate: GateService
  public var blocks: BlockService
  public var account: AccountService
  public var network: NetworkService
  public var config: ConfigService
  public var analytics: Analytics

  @MainActor
  public static func live() throws -> Dependencies {
    try make(database: AppDatabase.live(), keychain: Keychain(), analytics: Analytics.live())
  }

  public static func preview(apiBaseURL: URL = APIClient.configuredBaseURL) throws -> Dependencies {
    try make(
      database: AppDatabase.inMemory(), keychain: .inMemory(), analytics: .disabled,
      apiBaseURL: apiBaseURL)
  }

  public static func test() throws -> Dependencies {
    try make(database: AppDatabase.inMemory(), keychain: Keychain(service: "com.advan.toll.test"), analytics: .disabled)
  }

  static func make(
    database: AppDatabase, keychain: Keychain, analytics: Analytics, apiBaseURL: URL = APIClient.configuredBaseURL
  ) throws -> Dependencies {
    let clock = SystemClock()
    let store = LocalStore(database: database)
    let api = APIClient(baseURL: apiBaseURL) { keychain.string(.sessionToken) }
    let sync = SyncEngine(store: store, api: api, keychain: keychain)
    let config = ConfigService(api: api, store: store)
    return Dependencies(
      clock: clock, store: store, api: api, keychain: keychain, sync: sync,
      gate: GateService(store: store, sync: sync, config: .defaults, clock: clock, analytics: analytics),
      blocks: BlockService(store: store, sync: sync, clock: clock, analytics: analytics),
      account: AccountService(api: api, store: store, sync: sync, keychain: keychain, analytics: analytics),
      network: NetworkService(api: api, store: store, analytics: analytics),
      config: config, analytics: analytics)
  }
}

/// Remote config (E11.50): fetched at launch, cached, merged over the §14 defaults. Solo mode never
/// touches the network (spec §13), so it runs on the cached or default values.
public actor ConfigService {
  let api: APIClient
  let store: LocalStore
  private(set) var current: TollConfig = .defaults

  public init(api: APIClient, store: LocalStore) {
    self.api = api
    self.store = store
  }

  public func load() async -> TollConfig {
    if let data = try? await store.setting("config", as: Data.self) {
      current = TollConfig.merging(remoteJSON: data)
    }
    return current
  }

  public func refresh(signedIn: Bool) async -> TollConfig {
    guard signedIn else { return current }
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    guard let data = try? await api.send("GET", "config", query: ["v": version], body: nil, contentType: nil, idempotencyKey: nil)
    else { return current }
    current = TollConfig.merging(remoteJSON: data)
    try? await store.setSetting("config", data)
    return current
  }
}
