import MapKit
import SwiftUI
import TollCore
import TollUI

/// Setup 3 (spec §7): the map centred on where the user is, home drawn around it. The privacy line is
/// on screen before the location prompt appears.
struct HomeMapView: View {
  let model: SetupModel
  @State private var camera = MapCameraPosition.userLocation(fallback: .automatic)

  var body: some View {
    SetupPage(step: SetupModel.Step.home.number, title: Copy.Setup.homeTitle) {
      SetupLine(Copy.Setup.homeLine, .subhead)
      map
      if model.locating { SetupLine(Copy.Setup.finding, .caption) }
      if model.noFix { SetupLine(Copy.Setup.noFix, .caption) }
      if blocked { SetupLine(Copy.Setup.homeWithoutLocation) }
    } actions: {
      if blocked {
        PrimaryButton(Copy.Setup.continueWithout) { model.go(.permissions) }
      } else if model.noFix {
        PrimaryButton(Copy.Setup.tryAgain) { Task { await model.retryLocate() } }
      } else {
        PrimaryButton(Copy.Setup.thisIsHome) { model.go(.permissions) }
          .disabled(model.home == nil)
      }
    }
    // A moment on screen first, so the line is read before the prompt covers it.
    .task {
      try? await Task.sleep(for: .seconds(1))
      await model.locate()
    }
    .onChange(of: model.app.location) { Task { await model.locate() } }
    .onChange(of: model.home) { _, home in
      guard let home else { return }
      camera = .region(
        MKCoordinateRegion(
          center: CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude),
          latitudinalMeters: home.radiusMeters * 6, longitudinalMeters: home.radiusMeters * 6))
    }
  }

  private var blocked: Bool {
    model.app.location == .denied || model.app.location == .approximate
  }

  private var map: some View {
    Map(position: $camera, interactionModes: []) {
      if let home = model.home {
        MapCircle(
          center: CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude),
          radius: home.radiusMeters
        )
        .foregroundStyle(TollColor.accentSoft)
        .stroke(TollColor.accent, lineWidth: 2)
      }
    }
    .frame(height: 280)
    .clipShape(RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
    .accessibilityElement()
    .accessibilityLabel(Copy.Setup.mapLabel)
  }
}
