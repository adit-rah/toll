#if os(iOS)
  @preconcurrency import FamilyControls
  import Foundation

  /// Individual (not family) authorization on this device (spec §11.1).
  public enum ScreenTimeAuthorization {
    public enum State: Sendable, Equatable {
      case notDetermined, denied, approved
    }

    @MainActor
    public static var state: State {
      switch AuthorizationCenter.shared.authorizationStatus {
      case .approved: .approved
      case .denied: .denied
      default: .notDetermined
      }
    }

    @MainActor
    public static func request() async -> State {
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
      } catch {
        return .denied
      }
      return state
    }
  }
#endif
