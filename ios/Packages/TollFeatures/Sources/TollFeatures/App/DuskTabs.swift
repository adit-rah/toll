import SwiftUI
import TollCore
import TollUI

/// The three tabs (D63). Tonight is a glance: the state, the day strip and the unlocks. Your sleep
/// holds the week and the trends (#88). Blocks holds every block, Sleep included, so Home no longer
/// carries them. Settings stays the gear on Tonight.
enum DuskTab: Hashable {
  case tonight, sleep, blocks
}

struct DuskTabs<Tonight: View>: View {
  @Binding var tab: DuskTab
  @Binding var tonightPath: [HomeRoute]
  @Binding var blocksPath: [HomeRoute]
  let model: AppModel
  let sleep: YourSleep
  let log: [TollCore.Transition]
  let openPurchase: () -> Void
  @ViewBuilder let tonight: Tonight

  var body: some View {
    TabView(selection: $tab) {
      Tab(Copy.Tabs.tonight, systemImage: TollSymbol.sleep.name, value: DuskTab.tonight) {
        NavigationStack(path: $tonightPath) {
          tonight
            .homeNavigation()
            .navigationDestination(for: HomeRoute.self) { route in
              HomeDestination(model: model, route: route, openPurchase: openPurchase)
            }
        }
      }
      Tab(Copy.Tabs.sleep, systemImage: TollSymbol.insights.name, value: DuskTab.sleep) {
        NavigationStack {
          InsightsView(log: log, sleep: sleep)
        }
      }
      Tab(Copy.Tabs.blocks, systemImage: TollSymbol.blocks.name, value: DuskTab.blocks) {
        NavigationStack(path: $blocksPath) {
          BlocksView(model: model)
            .navigationDestination(for: HomeRoute.self) { route in
              HomeDestination(model: model, route: route, openPurchase: openPurchase)
            }
        }
      }
    }
    .tint(TollColor.accent)
  }
}
