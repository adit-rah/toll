import Foundation
import Observation
import TollCore
import TollData
import TollScreenTime
import UIKit

/// Set up 1 · You (flows §3): photo, name (prefilled from Apple), handle with a live check.
@MainActor
@Observable
public final class YouModel {
  public enum HandleState: Equatable { case unknown, checking, available, taken([String]), invalid }

  let app: AppModel
  public var name = ""
  public var handle = "" { didSet { if handle != oldValue { scheduleCheck() } } }
  public private(set) var handleState: HandleState = .unknown
  public private(set) var nameRinged = false
  public private(set) var photo: Data?
  public private(set) var isSaving = false
  public private(set) var error: String?
  private var check: Task<Void, Never>?

  public init(app: AppModel) {
    self.app = app
  }

  public func load() async {
    let appleName = try? await app.deps.store.setting("appleName", as: String.self)
    name = app.me?.displayName ?? appleName ?? ""
    if let existing = app.me?.handle {
      handle = existing
    } else if !name.isEmpty, let suggestion = try? await app.deps.account.suggestHandle(for: name) {
      handle = suggestion
    }
  }

  static func isValidHandle(_ text: String) -> Bool {
    (3...20).contains(text.count) && text.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "_") }
  }

  private func scheduleCheck() {
    check?.cancel()
    let candidate = handle.lowercased()
    guard Self.isValidHandle(candidate) else {
      handleState = candidate.isEmpty ? .unknown : .invalid
      return
    }
    handleState = .checking
    check = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled, let self else { return }
      let result = try? await self.app.deps.account.handleAvailability(candidate)
      guard !Task.isCancelled, self.handle.lowercased() == candidate else { return }
      if let result {
        self.handleState = result.available ? .available : .taken(result.suggestions)
      } else {
        self.handleState = .unknown
      }
    }
  }

  public func setPhoto(_ data: Data) {
    photo = PhotoProcessing.jpeg(from: data, maxPixels: app.config.identity.photoMaxPx)
  }

  public func save() async {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (2...24).contains(trimmed.count) else {
      nameRinged = true
      return
    }
    nameRinged = false
    isSaving = true
    defer { isSaving = false }
    do {
      var me = try await app.deps.account.update(
        MePatch(displayName: trimmed, handle: handle.lowercased(), timezone: TimeZone.current.identifier))
      if let photo { me = try await app.deps.account.uploadPhoto(photo) }
      app.updated(me)
      app.deps.analytics.send(.onboardingStep(step: "you", skipped: false))
      await app.reroute()
    } catch let error as APIError {
      switch error.code {
      case "handle_taken": handleState = .taken([])
      case "handle_invalid": handleState = .invalid
      case "name_invalid": nameRinged = true
      default: self.error = Copy.Errors.generic
      }
    } catch {
      self.error = Copy.Errors.generic
    }
  }
}

/// Set up 2 · Permissions (flows §4): one Allow runs both system sheets; no skip.
@MainActor
@Observable
public final class PermissionsModel {
  public enum Phase: Equatable { case ready, denied, deniedForGood }

  let app: AppModel
  public private(set) var phase: Phase = .ready
  public private(set) var notificationsAllowed: Bool?
  public private(set) var isWorking = false

  public init(app: AppModel) {
    self.app = app
  }

  public func allow() async {
    if phase == .deniedForGood, let url = URL(string: UIApplication.openSettingsURLString) {
      await UIApplication.shared.open(url)
      return
    }
    isWorking = true
    defer { isWorking = false }
    let state = await ScreenTimeAuthorization.request()
    app.deps.analytics.send(.screenTimeAuth(granted: state == .approved))
    guard state == .approved else {
      phase = phase == .denied ? .deniedForGood : .denied
      return
    }
    let allowed = await NotificationPermission.request()
    notificationsAllowed = allowed
    await app.deps.gate.setNotificationsAllowed(allowed)
    if !allowed { _ = try? await app.deps.account.update(MePatch(notifyEnabled: false)) }
    app.deps.analytics.send(.onboardingStep(step: "permissions", skipped: false))
    await app.reroute()
  }

  /// Back from the Settings app: if permission is now granted, the step completes.
  public func recheck() async {
    if ScreenTimeAuthorization.state == .approved {
      await app.deps.gate.setNotificationsAllowed(await NotificationPermission.isAllowed())
      await app.reroute()
    }
  }
}
