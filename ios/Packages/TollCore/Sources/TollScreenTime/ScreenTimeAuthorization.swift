#if os(iOS)
  @preconcurrency import FamilyControls
  import Foundation

  /// Individual (not family) authorization on this device (spec §11.1).
  public enum ScreenTimeAuthorization {
    public enum State: Sendable, Equatable {
      case notDetermined, denied, approved
    }

    #if DEBUG
      /// Set by the demo launch: the simulator cannot grant Family Controls (docs/renders.md).
      @MainActor public static var simulated: State?
    #endif

    @MainActor
    public static var state: State {
      #if DEBUG
        if let simulated { return simulated }
      #endif
      switch AuthorizationCenter.shared.authorizationStatus {
      case .approved: .approved
      case .denied: .denied
      default: .notDetermined
      }
    }

    @MainActor
    public static func request() async -> State {
      #if DEBUG
        if let simulated { return simulated }
      #endif
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
      } catch {
        return .denied
      }
      return state
    }
  }
#endif
