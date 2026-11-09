import SwiftUI
import TollCore
import TollUI

/// Launch routes to Welcome, a setup step, or the tabs (spec §9). The gate sits above all of it.
public struct RootView: View {
  @Bindable var model: AppModel
  @Environment(\.scenePhase) private var scenePhase

  public init(model: AppModel) {
    self.model = model
  }

  public var body: some View {
    Group {
      switch model.route {
      case .none: TollColor.bg.ignoresSafeArea()
      case .welcome: WelcomeFlow(app: model)
      case .you: YouView(app: model)
      case .permissions: PermissionsView(app: model)
      case .blocks(let returning): SetupBlocksView(app: model, returning: returning)
      case .findFriends: FindFriendsView(app: model, isSetup: true)
      case .home: MainTabs(app: model)
      }
    }
    .animation(Motion.movement, value: model.route)
    .task {
      await model.launch()
      await model.foreground()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await model.foreground() } }
    }
    .onOpenURL { url in Task { await model.handle(url: url) } }
    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
      if let url = activity.webpageURL { Task { await model.handle(url: url) } }
    }
    .sheet(isPresented: $model.showsSignInSheet) {
      WelcomeFlow(app: model, asSheet: true)
    }
  }
}

/// Home · Insights · People (design §2.7). The wait card covers the tab bar while it is up.
struct MainTabs: View {
  @Bindable var app: AppModel

  var body: some View {
    TabView(selection: $app.tab) {
      Tab(Copy.Home.tab, systemImage: "house", value: AppTab.home) {
        HomeView(app: app)
      }
      Tab(Copy.Insights.title, systemImage: "chart.bar", value: AppTab.insights) {
        InsightsView(app: app)
      }
      Tab(Copy.People.title, systemImage: "person.2", value: AppTab.people) {
        PeopleView(app: app)
      }
    }
    .tint(TollColor.accent)
    .minimizingTabBarOnScroll()
    .overlay { GateLayer(app: app) }
  }
}

extension View {
  @ViewBuilder
  func minimizingTabBarOnScroll() -> some View {
    if #available(iOS 26, *) {
      tabBarMinimizeBehavior(.onScrollDown)
    } else {
      self
    }
  }
}
