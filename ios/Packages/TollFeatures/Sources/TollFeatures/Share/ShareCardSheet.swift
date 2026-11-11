import CoreTransferable
import SwiftUI
import TollCore
import TollData
import TollUI
import UniformTypeIdentifiers

/// Share cards (insights §6): user-initiated, rendered from the same views, story or square, light or
/// dark. Friends' names never appear (S-5); the invite link is always on the card (S-4).
struct ShareCardSheet: View {
  enum Card: String, CaseIterable, Identifiable, Sendable {
    case week, day, gates, friends, school, exam
    var id: String { rawValue }
  }

  let model: InsightsModel
  @Environment(\.colorScheme) private var systemScheme
  @Environment(\.dismiss) private var dismiss
  @State private var card: Card = .week
  @State private var format: ShareCardFormat = .story
  // Nil follows the phone (S-2) from the first frame; a stored default would flash light first.
  @State private var darkOverride: Bool?
  @State private var showName = true
  @State private var invite: Invite?

  var body: some View {
    NavigationStack {
      VStack(spacing: TollSpacing.grid * 2) {
        cardPicker
        preview
        options
      }
      .padding(.top, TollSpacing.grid)
      .tollGutter()
      .navigationTitle(Copy.Insights.share)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button(Copy.Insights.cancel) { dismiss() } } }
      .tollBottomBar(background: TollColor.bg) { shareButton }
    }
    .task { invite = try? await model.app.deps.network.invite() }
  }

  private var isDark: Bool { darkOverride ?? (systemScheme == .dark) }
  private var displayName: String? { showName ? model.app.me?.displayName : nil }
  private var shortLink: String { (invite?.url ?? "").replacingOccurrences(of: "https://", with: "") }

  private var available: [Card] {
    var cards: [Card] = [.week, .day, .gates]
    if model.friends?.friendsHeldPercent != nil { cards.append(.friends) }
    if model.school?.enough == true { cards.append(.school) }
    if model.examCaption != nil { cards.append(.exam) }
    return cards
  }

  private func title(_ card: Card) -> String {
    switch card {
    case .week: Copy.Insights.cardWeek
    case .day: Copy.Insights.cardDay
    case .gates: Copy.Insights.cardGates
    case .friends: Copy.Insights.cardFriends
    case .school: Copy.Insights.cardSchool
    case .exam: Copy.Insights.cardExam
    }
  }

  private var cardPicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: TollSpacing.grid) {
        ForEach(available) { option in
          ChoiceChip(title(option), isSelected: option == card) { card = option }
        }
      }
    }
  }

  /// The card at its real size, scaled to whatever the sheet has left: the controls keep their
  /// place on a small phone and the picture gives way, never the other way round.
  private var preview: some View {
    GeometryReader { proxy in
      let size = format.size
      let scale = max(0.1, min(1, proxy.size.width / size.width, proxy.size.height / size.height))
      let outline = RoundedRectangle(cornerRadius: TollRadius.card / scale, style: .continuous)
      ShareCardView(
        card: card, format: format, isDark: isDark, name: displayName, range: model.me.weekRange, link: shortLink,
        model: model
      )
      .clipShape(outline)
      // The canvas can match the sheet behind it; the hairline is the preview's edge, not the card's.
      .overlay { outline.strokeBorder(TollColor.separator, lineWidth: 1 / scale) }
      .scaleEffect(scale)
      .frame(width: size.width * scale, height: size.height * scale)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .animation(Motion.movement, value: isDark)
    }
    .frame(minHeight: 160)
  }

  private var options: some View {
    VStack(spacing: TollSpacing.grid) {
      HStack(spacing: TollSpacing.rowLeadingGap) {
        Picker(Copy.Insights.story, selection: $format) {
          Text(Copy.Insights.story).tag(ShareCardFormat.story)
          Text(Copy.Insights.square).tag(ShareCardFormat.square)
        }
        Picker(Copy.Insights.light, selection: Binding(get: { isDark }, set: { darkOverride = $0 })) {
          Text(Copy.Insights.light).tag(false)
          Text(Copy.Insights.dark).tag(true)
        }
      }
      .pickerStyle(.segmented)
      if model.app.me?.displayName != nil {
        Toggle(Copy.Insights.showName, isOn: $showName)
          .font(TollFont.body)
          .frame(minHeight: TollSpacing.minTapTarget)
      }
    }
  }

  private var shareButton: some View {
    ShareLink(item: export, preview: SharePreview(title(card))) { Text(Copy.Insights.share) }
      .buttonStyle(.tollPrimary)
      .simultaneousGesture(
        TapGesture().onEnded {
          model.app.deps.analytics.send(.shareCard(type: card.rawValue, format: format == .story ? "story" : "square"))
        })
  }

  /// What the card shows, copied out as plain values so the image can be drawn later without this sheet.
  private var export: ShareCardImage {
    let chosen = card
    let shape = format
    let dark = isDark
    let name = displayName
    let range = model.me.weekRange
    let link = shortLink
    let source = model
    return ShareCardImage {
      let view = ShareCardView(
        card: chosen, format: shape, isDark: dark, name: name, range: range, link: link, model: source)
      let renderer = ImageRenderer(content: view)
      renderer.scale = 3
      return renderer.uiImage?.pngData()
    }
  }
}

/// Rendered at 3× from the same view (S-2), and only when a share target asks for the image: a
/// 1080 × 1920 bitmap on every toggle is what made the preview stutter.
struct ShareCardImage: Transferable, Sendable {
  let render: @MainActor @Sendable () -> Data?

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .png) { image in
      guard let data = await image.render() else { throw CocoaError(.fileWriteUnknown) }
      return data
    }
  }
}
