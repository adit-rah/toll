import SwiftUI
import TollFeatures

@main
struct TollApp: App {
  @UIApplicationDelegateAdaptor(TollAppDelegate.self) private var delegate

  var body: some Scene {
    WindowGroup {
      RootView(model: delegate.model)
    }
  }
}
