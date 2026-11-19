import MapKit
import SwiftUI
import TollCore
import TollUI

/// Setup 2 (the canvas): the map centred on where the user is, home drawn around it; Move lets the map
/// be dragged under the circle. The privacy line is on screen before the location prompt appears.
struct HomeMapView: View {
  let model: SetupModel
  @State private var camera = MapCameraPosition.userLocation(fallback: .automatic)

  var body: some View {
    SetupPage(step: SetupModel.Step.home.number, title: Copy.Setup.homeTitle) {
      map
      if blocked {
        SetupLine(Copy.Setup.homeWithoutLocation)
      } else {
        Card {
          CardRow(
            Copy.Setup.currentLocation,
            detail: model.moving ? Copy.Setup.movingDetail : Copy.Setup.coversBuilding
          ) {
            IconTile("location.fill")
          } trailing: {
            Button(model.moving ? Copy.Setup.done : Copy.Setup.move) { model.moving.toggle() }
              .buttonStyle(.tollQuiet)
              .disabled(model.home == nil)
          }
        }
      }
      if model.locating { Footnote(Copy.Setup.finding) }
      if model.noFix { Footnote(Copy.Setup.noFix) }
      Footnote(Copy.Setup.homeLine, symbol: "lock")
    } actions: {
      if blocked {
        PrimaryButton(Copy.Setup.continueWithout) { model.go(.permissions) }
      } else if model.noFix {
        PrimaryButton(Copy.Setup.tryAgain) { Task { await model.retryLocate() } }
      } else {
        PrimaryButton(Copy.Setup.thisIsHome) {
          model.moving = false
          model.go(.permissions)
        }
        .disabled(model.home == nil)
      }
    }
    // A moment on screen first, so the line is read before the prompt covers it.
    .task {
      try? await Task.sleep(for: .seconds(1))
      await model.locate()
    }
    .onChange(of: model.app.location) { Task { await model.locate() } }
    .onChange(of: model.home?.id) { center(on: model.home) }
  }

  private var blocked: Bool {
    model.app.location == .denied || model.app.location == .approximate
  }

  private var map: some View {
    Map(position: $camera, interactionModes: model.moving ? [.pan, .zoom] : []) {
      if let home = model.home {
        let center = CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
        MapCircle(center: center, radius: home.radiusMeters)
          .foregroundStyle(TollColor.accentSoft)
          .stroke(TollColor.accent, lineWidth: 2)
        Annotation(Copy.Setup.mapPin, coordinate: center) {
          Circle()
            .fill(TollColor.accent)
            .stroke(TollColor.bg, lineWidth: 3)
            .frame(width: 18, height: 18)
        }
      }
    }
    .onMapCameraChange(frequency: .onEnd) { context in
      guard model.moving else { return }
      model.moveHome(
        latitude: context.region.center.latitude, longitude: context.region.center.longitude)
    }
    .frame(height: 280)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .accessibilityElement()
    .accessibilityLabel(Copy.Setup.mapLabel)
  }

  private func center(on home: Place?) {
    guard let home else { return }
    camera = .region(
      MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude),
        latitudinalMeters: home.radiusMeters * 6, longitudinalMeters: home.radiusMeters * 6))
  }
}
