#if DEBUG
  import SwiftUI
  import TollCore
  import TollData
  import TollScreenTime

  struct DemoSetup: View {
    @State private var model: SetupModel

    init(app: AppModel, path: [SetupModel.Step]) {
      _model = State(initialValue: SetupModel(app: app, path: path))
    }

    var body: some View {
      SetupFlowContent(model: model)
        .task {
          let scenario = DemoScenario.current
          ScreenTimeAuthorization.simulated = scenario?.screenTime
          LocationAccess.simulated = scenario?.location
          model.weekendsDiffer = scenario == .wakeWeekends
          model.app.readPermissions()
        }
    }
  }

  /// The set-home sheet with home placed in London: the simulator has no one to answer the prompt.
  struct DemoSetHome: View {
    @State private var model: SetHomeModel

    init(app: AppModel, path: [SetHomeModel.Step]) {
      let model = SetHomeModel(app: app, path: path)
      model.placesHome = false
      if !model.mapBlocked {
        model.home = Place(
          name: Copy.Setup.homeName, latitude: 51.5246, longitude: -0.0786, radiusMeters: 150)
      }
      _model = State(initialValue: model)
    }

    var body: some View {
      SetHomeFlowContent(model: model)
    }
  }
#endif
