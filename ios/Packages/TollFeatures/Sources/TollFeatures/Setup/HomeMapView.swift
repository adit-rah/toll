import MapKit
import SwiftUI
import TollCore
import TollUI

/// "Only when I'm home", first step (the canvas's map, offered after the first night, D68): the map
/// centred on where the user is, home drawn around it; Move lets the map be dragged under the circle.
/// The privacy line is on screen before the location prompt appears.
struct HomeMapView: View {
  let model: SetHomeModel
  @State private var camera = MapCameraPosition.userLocation(fallback: .automatic)

  var body: some View {
    SetupPage(
      step: SetHomeModel.mapStep, of: SetHomeModel.questions, title: Copy.Setup.homeTitle,
      endsWithLink: blocked
    ) {
      map.padding(.top, 24)
      if blocked {
        SetupLine(Copy.Setup.homeWithoutLocation).padding(.top, 16)
      } else {
        Card {
          CardRow(
            Copy.Setup.currentLocation,
            detail: model.moving ? Copy.Setup.movingDetail : Copy.Setup.coversBuilding,
            size: .place
          ) {
            IconTile(.location)
          } trailing: {
            Button(model.moving ? Copy.Setup.done : Copy.Setup.move) { model.moving.toggle() }
              .tollType(.link, TollColor.accent)
              .frame(minWidth: TollSpacing.minTapTarget, minHeight: TollSpacing.minTapTarget)
              .disabled(model.home == nil)
          }
        }
        .padding(.top, 16)
      }
      if model.locating { Footnote(Copy.Setup.finding).padding(.top, 14) }
      if model.noFix { Footnote(Copy.Setup.noFix).padding(.top, 14) }
      Footnote(Copy.Setup.homeLine, symbol: .privacy).padding(.top, 14)
    } actions: {
      if blocked {
        // Only Settings can turn location back on; leaving keeps the night running anywhere.
        PrimaryButton(action: openSystemSettings) {
          HStack(spacing: 8) {
            Text(Copy.Setup.openSettings)
            Image(symbol: .openSettings).unredacted().accessibilityHidden(true)
          }
        }
        QuietButton(Copy.Setup.notNow, type: .smallQuiet) { model.cancel() }
      } else if model.noFix {
        PrimaryButton(Copy.Setup.tryAgain) { Task { await model.retryLocate() } }
      } else {
        PrimaryButton(Copy.Setup.thisIsHome) { model.homeChosen() }
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
    // A home already set opens on its circle, not on wherever the phone is.
    .onAppear { center(on: model.home) }
  }

  private var blocked: Bool { model.mapBlocked }

  private var map: some View {
    Map(position: $camera, interactionModes: model.moving ? [.pan, .zoom] : []) {
      if let home = model.home {
        let center = CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
        MapCircle(center: center, radius: home.radiusMeters)
          .foregroundStyle(TollColor.accentSoft)
          .stroke(TollColor.accent, lineWidth: 2)
        Annotation(Copy.Setup.mapPin, coordinate: center, anchor: .center) {
          VStack(spacing: 9) {
            Circle()
              .fill(TollColor.accent)
              .stroke(TollColor.bg, lineWidth: 3)
              .frame(width: 18, height: 18)
            Text(Copy.Setup.mapPin)
              .tollType(TollType(size: 12, lineHeight: 16, weight: .semibold, style: .caption))
              .foregroundStyle(TollColor.label)
              .padding(.horizontal, 10)
              .frame(height: 26)
              .background(TollColor.bg, in: Capsule())
          }
          .offset(y: 17.5)
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
