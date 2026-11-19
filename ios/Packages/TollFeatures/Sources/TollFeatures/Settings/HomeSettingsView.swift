import MapKit
import SwiftUI
import TollCore
import TollUI

/// Home: the region on a map, and a way to move it to where the user is now. During a block the move
/// waits (B-3).
struct HomeSettingsView: View {
  let model: AppModel
  @State private var locating = false
  @State private var noFix = false

  var body: some View {
    List {
      Section {
        if let home = model.draftPlace(model.sleepDraft?.place) {
          HomeMap(home: home)
            .listRowInsets(EdgeInsets())
          Text(Copy.Settings.homeSet)
        } else {
          Text(Copy.Settings.homeNotSet)
        }
      } footer: {
        Text(Copy.Settings.changesLater)
      }
      Section {
        Button(locating ? Copy.Settings.finding : Copy.Settings.moveHome) {
          Task { await moveHere() }
        }
        .disabled(locating)
        if noFix { Text(Copy.Settings.noFix).tollText(.subhead) }
      }
    }
    .navigationTitle(Copy.Settings.home)
  }

  private func moveHere() async {
    model.locationAccess.requestWhileUsing()
    locating = true
    defer { locating = false }
    let radius = model.config.home.radiusMeters
    guard let here = await model.locationAccess.here(radiusMeters: radius) else {
      noFix = true
      return
    }
    noFix = false
    // Home is a place blocks share: moving it moves every block at Home.
    if var home = model.draftPlace(model.sleepDraft?.place) {
      home.latitude = here.latitude
      home.longitude = here.longitude
      model.save(home)
    } else if var sleep = model.sleepDraft {
      let home = Place(
        name: Copy.Setup.homeName, latitude: here.latitude, longitude: here.longitude,
        radiusMeters: radius)
      model.save(home)
      sleep.place = home.id
      model.save(sleep)
    }
  }
}

struct HomeMap: View {
  let home: Place

  var body: some View {
    let center = CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
    Map(
      initialPosition: .region(
        MKCoordinateRegion(
          center: center, latitudinalMeters: home.radiusMeters * 6,
          longitudinalMeters: home.radiusMeters * 6)),
      interactionModes: []
    ) {
      MapCircle(center: center, radius: home.radiusMeters)
        .foregroundStyle(TollColor.accentSoft)
        .stroke(TollColor.accent, lineWidth: 2)
    }
    .frame(height: 220)
    .accessibilityElement()
    .accessibilityLabel(Copy.Setup.mapLabel)
  }
}
