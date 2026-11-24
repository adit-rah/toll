import MapKit
import SwiftUI
import TollCore
import TollUI

/// Block · place, and Block · place: anywhere (the canvas), pushed from the editor: search, Apple
/// Maps' results, the current location or Anywhere; then the map with the circle and its size. A
/// block with no place runs on its hours alone (D37).
struct PlacePicker: View {
  let app: AppModel
  let chosen: (Place?) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var place: Place?
  @State private var anywhere: Bool
  @State private var query = ""
  @State private var results: [Result] = []
  @State private var camera = MapCameraPosition.userLocation(fallback: .automatic)

  struct Result: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
  }

  /// Building, Block, Campus (sticky note s1): iOS is unreliable under 150 m.
  private let sizes: [(String, Double)] = [
    (Copy.Blocks.building, 150), (Copy.Blocks.street, 300), (Copy.Blocks.campus, 600),
  ]

  init(app: AppModel, place: Place?, chosen: @escaping (Place?) -> Void) {
    self.app = app
    self.chosen = chosen
    _place = State(initialValue: place)
    _anywhere = State(initialValue: place == nil)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ScreenTitle(Copy.Blocks.whereTitle, kind: .pushed)
        TextField(Copy.Blocks.search, text: $query)
          .tollType(TollType(size: 16, lineHeight: 21, weight: .regular, style: .callout))
          .foregroundStyle(TollColor.label)
          .submitLabel(.search)
          .onSubmit { Task { await search() } }
          .padding(.horizontal, 14)
          .frame(minHeight: 48)
          .background(TollColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          .padding(.top, 16)
        Card {
          option(
            Copy.Blocks.anywhere, detail: Copy.Setup.anywhereDetail, symbol: .anywhere,
            selected: anywhere
          ) { anywhere = true }
          if let place, results.isEmpty {
            option(place.name, detail: nil, symbol: .place, selected: !anywhere) {
              anywhere = false
            }
          }
          ForEach(results.prefix(3)) { result in
            option(
              result.name, detail: result.address, symbol: .place,
              selected: !anywhere && place?.name == result.name
            ) { use(result) }
          }
          Button {
            Task { await here() }
          } label: {
            CardRow(Copy.Blocks.currentLocation, size: .compact) {
              IconTile(.location, accent: false)
            }
          }
          .buttonStyle(.plain)
        }
        .padding(.top, 12)
        if anywhere || place == nil {
          NoteCard(Copy.Blocks.anywhereNote, symbol: .anywhere).padding(.top, 14)
        } else if let place {
          map(place).padding(.top, 14)
          sizeChips.padding(.top, 14)
        }
      }
      .tollGutter()
      .padding(.bottom, 24)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(TollColor.bg)
    .animation(Motion.stateChange, value: anywhere)
    .tollBottomBar {
      PrimaryButton(anywhere || place == nil ? Copy.Blocks.useAnywhere : Copy.Blocks.usePlace) {
        chosen(anywhere ? nil : place)
        dismiss()
      }
    }
    .tollPushed(Copy.Blocks.whereTitle)
    .toolbar(.hidden, for: .tabBar)
    .onAppear { center() }
  }

  private func option(
    _ title: String, detail: String?, symbol: TollSymbol, selected: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      CardRow(title, detail: detail) {
        IconTile(symbol, accent: selected)
      } trailing: {
        if selected {
          Image(symbol: .done).unredacted()
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(TollColor.accent)
            .accessibilityHidden(true)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func map(_ place: Place) -> some View {
    Map(position: $camera, interactionModes: [.pan, .zoom]) {
      let center = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
      MapCircle(center: center, radius: place.radiusMeters)
        .foregroundStyle(TollColor.accentSoft)
        .stroke(TollColor.accent, lineWidth: 2)
      Annotation(place.name, coordinate: center, anchor: .center) {
        VStack(spacing: 9) {
          Circle().fill(TollColor.accent).stroke(TollColor.bg, lineWidth: 3)
            .frame(width: 18, height: 18)
          Text(place.name)
            .tollType(TollType(size: 12, lineHeight: 16, weight: .semibold, style: .caption))
            .foregroundStyle(TollColor.label)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(TollColor.bg, in: Capsule())
        }
        .offset(y: 17.5)
      }
    }
    .onMapCameraChange(frequency: .onEnd) { context in
      guard var moved = self.place else { return }
      moved.latitude = context.region.center.latitude
      moved.longitude = context.region.center.longitude
      self.place = moved
    }
    .frame(height: 196)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .accessibilityElement()
    .accessibilityLabel(Copy.Setup.mapLabel)
  }

  private var sizeChips: some View {
    HStack(spacing: 8) {
      ForEach(sizes, id: \.1) { size in
        let selected = place?.radiusMeters == size.1
        Button {
          place?.radiusMeters = size.1
          center()
        } label: {
          Text(size.0)
            .tollType(.trailing, selected ? TollColor.onAccent : TollColor.label2)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(
              selected ? TollColor.accent : TollColor.surface,
              in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
      }
    }
    .tollHaptic(.selection, trigger: place?.radiusMeters)
  }

  private func search() async {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    let items = (try? await MKLocalSearch(request: request).start().mapItems) ?? []
    results = items.map {
      Result(
        name: $0.name ?? query, address: $0.address?.shortAddress,
        latitude: $0.location.coordinate.latitude, longitude: $0.location.coordinate.longitude)
    }
    if let first = results.first { use(first) }
  }

  private func use(_ result: Result) {
    set(name: result.name, latitude: result.latitude, longitude: result.longitude)
  }

  private func here() async {
    app.locationAccess.requestWhileUsing()
    guard let fix = await app.locationAccess.here(radiusMeters: place?.radiusMeters ?? 150) else {
      return
    }
    results = []
    set(
      name: place?.name ?? Copy.Blocks.currentLocation, latitude: fix.latitude,
      longitude: fix.longitude)
  }

  /// Keeps the place's id when it is moved, so every block there moves with it.
  private func set(name: String, latitude: Double, longitude: Double) {
    var next =
      place ?? Place(name: name, latitude: latitude, longitude: longitude, radiusMeters: 150)
    next.name = name
    next.latitude = latitude
    next.longitude = longitude
    place = next
    anywhere = false
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
