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
        if let home = model.draft.home {
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
    guard let point = await model.locationAccess.here(radiusMeters: model.config.home.radiusMeters)
    else {
      noFix = true
      return
    }
    noFix = false
    var edit = model.draft
    edit.home = point
    model.submit(edit)
  }
}

struct HomeMap: View {
  let home: HomePoint

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
