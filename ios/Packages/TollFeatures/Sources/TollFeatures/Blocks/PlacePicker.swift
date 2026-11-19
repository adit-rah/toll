import MapKit
import SwiftUI
import TollCore
import TollUI

/// Where? (the design canvas): search, or the current location, then drag the map under the circle and
/// pick its size. "Anywhere" leaves the block without a place.
struct PlacePicker: View {
  let app: AppModel
  let chosen: (Place?) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var place: Place?
  @State private var query = ""
  @State private var camera = MapCameraPosition.userLocation(fallback: .automatic)

  /// The canvas's three sizes.
  private let sizes: [(String, Double)] = [
    (Copy.Blocks.building, 150), (Copy.Blocks.street, 300), (Copy.Blocks.campus, 600),
  ]

  init(app: AppModel, place: Place?, chosen: @escaping (Place?) -> Void) {
    self.app = app
    self.chosen = chosen
    _place = State(initialValue: place)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: TollSpacing.groupGap) {
          ScreenTitle(Copy.Blocks.whereTitle)
          TextField(Copy.Blocks.search, text: $query)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(
              TollColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .submitLabel(.search)
            .onSubmit { Task { await search() } }
          map
          if place != nil {
            Picker(Copy.Blocks.place, selection: radius) {
              ForEach(sizes, id: \.1) { Text($0.0).tag($0.1) }
            }
            .pickerStyle(.segmented)
            TextField(Copy.Blocks.name, text: name).font(TollFont.bodyMedium)
          }
          QuietButton(Copy.Blocks.currentLocation) { Task { await here() } }
          QuietButton(Copy.Blocks.noPlace, tone: .secondary) {
            chosen(nil)
            dismiss()
          }
        }
        .tollGutter()
        .padding(.bottom, TollSpacing.sectionGap)
      }
      .background(TollColor.bg)
      .tollBottomBar(background: TollColor.bg) {
        PrimaryButton(Copy.Blocks.usePlace) {
          chosen(place)
          dismiss()
        }
        .disabled(place == nil)
      }
    }
    .tint(TollColor.accent)
    .onAppear { center() }
  }

  private var map: some View {
    Map(position: $camera, interactionModes: [.pan, .zoom]) {
      if let place {
        MapCircle(
          center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
          radius: place.radiusMeters
        )
        .foregroundStyle(TollColor.accentSoft)
        .stroke(TollColor.accent, lineWidth: 2)
      }
    }
    .onMapCameraChange(frequency: .onEnd) { context in
      guard var moved = place else { return }
      moved.latitude = context.region.center.latitude
      moved.longitude = context.region.center.longitude
      place = moved
    }
    .frame(height: 260)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .accessibilityElement()
    .accessibilityLabel(Copy.Setup.mapLabel)
  }

  private var radius: Binding<Double> {
    Binding(get: { place?.radiusMeters ?? 150 }, set: { place?.radiusMeters = $0 })
  }

  private var name: Binding<String> {
    Binding(get: { place?.name ?? "" }, set: { place?.name = $0 })
  }

  private func search() async {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else {
      return
    }
    let coordinate = item.location.coordinate
    set(name: item.name ?? query, latitude: coordinate.latitude, longitude: coordinate.longitude)
  }

  private func here() async {
    app.locationAccess.requestWhileUsing()
    guard let fix = await app.locationAccess.here(radiusMeters: place?.radiusMeters ?? 150) else {
      return
    }
    set(
      name: place?.name ?? Copy.Blocks.currentLocation, latitude: fix.latitude,
      longitude: fix.longitude)
  }

  /// Keeps the place's id when it is moved, so every block there moves with it.
  private func set(name: String, latitude: Double, longitude: Double) {
    var next =
      place
      ?? Place(name: name, latitude: latitude, longitude: longitude, radiusMeters: 150)
    next.latitude = latitude
    next.longitude = longitude
    if next.name.isEmpty || next.name == Copy.Blocks.currentLocation { next.name = name }
    place = next
    center()
  }

  private func center() {
    guard let place else { return }
    camera = .region(
      MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
        latitudinalMeters: place.radiusMeters * 6, longitudinalMeters: place.radiusMeters * 6))
  }
}
