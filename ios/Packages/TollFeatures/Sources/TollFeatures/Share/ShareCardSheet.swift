import Charts
import SwiftUI
import TollCore
import TollData
import TollUI

/// Share cards (insights §6): user-initiated, rendered from the same views, story or square, light or
/// dark. Friends' names never appear (S-5); the invite link is always on the card (S-4).
struct ShareCardSheet: View {
  enum Card: String, CaseIterable, Identifiable {
    case week, day, gates, friends, school, exam
    var id: String { rawValue }
  }

  let model: InsightsModel
  @Environment(\.colorScheme) private var systemScheme
  @Environment(\.dismiss) private var dismiss
  @State private var card: Card = .week
  @State private var format: ShareCardFormat = .story
  @State private var dark = false
  @State private var showName = true
  @State private var invite: Invite?
  @State private var rendered: Image?

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Picker(Copy.Insights.share, selection: $card) {
          ForEach(available) { Text(title($0)).tag($0) }
        }
        .pickerStyle(.menu)
        cardView
          .scaleEffect(format == .story ? 0.8 : 1)
          .frame(height: format == .story ? 520 : 360)
          .animation(Motion.movement, value: dark)
        HStack {
          Picker("", selection: $format) {
            Text(Copy.Insights.story).tag(ShareCardFormat.story)
            Text(Copy.Insights.square).tag(ShareCardFormat.square)
          }
          Picker("", selection: $dark) {
            Text(Copy.Insights.light).tag(false)
            Text(Copy.Insights.dark).tag(true)
          }
        }
        .pickerStyle(.segmented)
        Toggle(Copy.Insights.showName, isOn: $showName)
        if let rendered {
          ShareLink(item: rendered, preview: SharePreview(title(card), image: rendered)) { Text(Copy.Insights.share) }
            .buttonStyle(.tollPrimary)
            .simultaneousGesture(TapGesture().onEnded {
              model.app.deps.analytics.send(.shareCard(type: card.rawValue, format: format == .story ? "story" : "square"))
            })
        }
      }
      .tollGutter()
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button(Copy.Insights.cancel) { dismiss() } } }
    }
    .task {
      dark = systemScheme == .dark
      invite = try? await model.app.deps.network.invite()
      render()
    }
    .onChange(of: card) { render() }
    .onChange(of: format) { render() }
    .onChange(of: dark) { render() }
    .onChange(of: showName) { render() }
  }

  private var available: [Card] {
    var cards: [Card] = [.week, .day, .gates]
    if model.friends?.friendsHeldPercent != nil { cards.append(.friends) }
    if model.school?.enough == true { cards.append(.school) }
    if !model.me.examWeeks.isEmpty { cards.append(.exam) }
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

  private var cardView: some View {
    let week = model.thisWeekStart
    let range = "\(ChartLabels.day(week)) – \(ChartLabels.day(week.adding(days: 6)))"
    return ShareCardFrame(
      format: format, colorScheme: dark ? .dark : .light, displayName: showName ? model.app.me?.displayName : nil,
      dateRange: range, inviteLink: shortLink
    ) {
      ShareCardContent(card: card, model: model)
    }
  }

  private var shortLink: String {
    (invite?.url ?? "").replacingOccurrences(of: "https://", with: "")
  }

  /// Rendered at 3× from the same view (S-2).
  @MainActor
  private func render() {
    let renderer = ImageRenderer(content: cardView.environment(\.colorScheme, dark ? .dark : .light))
    renderer.scale = 3
    rendered = renderer.uiImage.map { Image(uiImage: $0) }
  }
}

struct ShareCardContent: View {
  let card: ShareCardSheet.Card
  let model: InsightsModel

  var body: some View {
    let me = model.me
    VStack(alignment: .leading, spacing: 16) {
      switch card {
      case .week:
        big("\(me.thisWeek.passes)")
        Text(Copy.ShareCards.week(me.thisWeek.passes, last: me.lastWeek.passes)).tollText(.headline)
        Text([me.thisWeek.heldPercent.map { "\(Copy.FriendDetail.held) \(Copy.percent($0))" },
              "\(Copy.Insights.cleanDays) \(me.thisWeek.cleanDays)", "\(Copy.Insights.waitMinutes) \(me.thisWeek.waitMinutes)"]
          .compactMap { $0 }.joined(separator: Copy.middleDot)).tollText(.subhead)
        Chart(me.days, id: \.day) {
          BarMark(x: .value("d", $0.day.description), y: .value("n", $0.passes))
            .foregroundStyle($0.day < model.thisWeekStart ? TollColor.neutralBar : TollColor.accent)
        }
        .chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 80)
      case .day:
        let today = me.days.last { $0.active } ?? me.days.last
        big("\(today?.passes ?? 0)")
        Text(Copy.ShareCards.day(today?.passes ?? 0)).tollText(.headline)
      case .gates:
        big(me.thisWeek.heldPercent.map(Copy.percent) ?? "—")
        Text(Copy.ShareCards.gates(me.thisWeek.heldPercent ?? 0)).tollText(.headline)
        Text("\(Copy.Insights.hits) \(me.thisWeek.hits)\(Copy.middleDot)\(Copy.Insights.heldLabel) \(me.thisWeek.held)\(Copy.middleDot)\(Copy.Insights.abandoned) \(me.thisWeek.abandoned)")
          .tollText(.subhead)
      case .friends:
        let held = model.friends?.friendsHeldPercent ?? 0
        big(Copy.percent(held))
        Text(Copy.ShareCards.friends(held)).tollText(.headline)
      case .school:
        let s = model.school
        big(s?.schoolHeldPercent.map(Copy.percent) ?? "—")
        Text(Copy.ShareCards.school(s?.school?.name ?? "", schoolPercent: s?.schoolHeldPercent ?? 0, mine: s?.myHeldPercent ?? 0))
          .tollText(.headline)
      case .exam:
        if let caption = model.examCaption { Text(caption).tollText(.headline) }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func big(_ text: String) -> some View {
    Text(text).font(.system(size: 96, weight: .semibold, design: .rounded)).monospacedDigit()
  }
}
