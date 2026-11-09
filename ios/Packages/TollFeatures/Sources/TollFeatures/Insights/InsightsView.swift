import Charts
import SwiftUI
import TollCore
import TollData
import TollUI

/// Insights (design §4.7): Me · Friends · School, a stack of cards, and the share button.
struct InsightsView: View {
  let app: AppModel
  @State private var model: InsightsModel?
  @State private var inviteShown = false

  var body: some View {
    NavigationStack {
      ScrollView {
        if let model {
          @Bindable var model = model
          VStack(spacing: 16) {
            Picker(Copy.Insights.title, selection: $model.segment) {
              Text(Copy.Insights.me).tag(InsightsModel.Segment.me)
              Text(Copy.Insights.friends).tag(InsightsModel.Segment.friends)
              Text(Copy.Insights.school).tag(InsightsModel.Segment.school)
            }
            .pickerStyle(.segmented)
            switch model.segment {
            case .me: MeInsightsView(model: model)
            case .friends: friends(model)
            case .school: school(model)
            }
          }
          .tollGutter()
          .animation(Motion.stateChange, value: model.segment)
        }
      }
      .background(TollColor.bgGrouped)
      .navigationTitle(Copy.Insights.title)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button { model?.shareShown = true } label: { Image(systemName: "square.and.arrow.up") }
            .accessibilityLabel(Copy.Insights.share)
        }
      }
      .sheet(isPresented: Binding(get: { model?.shareShown ?? false }, set: { model?.shareShown = $0 })) {
        if let model { ShareCardSheet(model: model) }
      }
      .sheet(isPresented: $inviteShown) { InviteSheet(app: app) }
    }
    .task {
      if model == nil { model = InsightsModel(app: app) }
      await model?.load()
    }
  }

  @ViewBuilder
  private func friends(_ model: InsightsModel) -> some View {
    if let data = model.friends, data.people.count > 1 {
      FriendsInsightsCards(model: model, data: data)
    } else {
      EmptyState(Copy.Insights.noFriends, actionTitle: Copy.Home.sendInvite) { inviteShown = true }
        .padding(.top, 40)
    }
  }

  @ViewBuilder
  private func school(_ model: InsightsModel) -> some View {
    if let data = model.school, data.enough {
      SchoolInsightsCards(model: model, data: data)
    } else if model.school?.school != nil || app.me?.school != nil {
      EmptyState(Copy.People.schoolBelowMinimum).padding(.top, 40)
    } else {
      VStack(spacing: 16) {
        EmptyState(Copy.Insights.notVerified)
        FindFriendsView(app: app, isSetup: false)
      }
      .padding(.top, 40)
    }
  }
}

/// I-10…I-14. Names appear only where friends already see each other's numbers (I-11).
struct FriendsInsightsCards: View {
  let model: InsightsModel
  let data: FriendsInsights

  var body: some View {
    VStack(spacing: 16) {
      if let distribution = data.distribution {
        let under = distribution.bins.first { $0.includesMe }?.to ?? 0
        let count = data.people.filter { !$0.isMe && $0.passes < under }.count
        ChartCard(
          title: Copy.Insights.distribution,
          caption: Copy.Insights.friendsUnder(count, of: data.people.count - 1, under: under)
        ) {
          BinBars(bins: distribution.bins.map { ($0.from, $0.to, $0.count, $0.includesMe) }, title: Copy.Insights.distribution)
        }
      }
      ChartCard(title: Copy.Insights.heldByFriend, caption: data.friendsHeldPercent.map(Copy.Home.friendsHeld)) {
        let rows = data.people.map { (name: $0.user?.displayName ?? Copy.Insights.me, held: $0.heldPercent ?? 0, me: $0.isMe) }
        Chart(rows, id: \.name) { row in
          BarMark(x: .value("held", row.held), y: .value("person", row.name))
            .foregroundStyle(row.me ? TollColor.accent : TollColor.neutralBar)
            .annotation(position: .trailing) { Text(Copy.percent(row.held)).tollText(.captionNumber) }
        }
        .chartXScale(domain: 0...100)
        .chartXAxis(.hidden)
        .frame(height: CGFloat(rows.count) * 32)
        .audioGraph(Copy.Insights.heldByFriend, labels: rows.map(\.name), values: rows.map { Double($0.held) })
      }
      ChartCard(title: Copy.Insights.whenFriendsReach, caption: peakCaption) {
        HourBars(
          values: data.friendsByHour.map(Double.init), overlay: data.myByHour.map(Double.init),
          lateStart: model.app.config.insights.lateStart, resetHour: model.app.config.gate.dayResetHour,
          title: Copy.Insights.whenFriendsReach)
      }
      ChartCard(title: Copy.Insights.weekOnWeek, caption: changeCaption) {
        Chart(data.weekly, id: \.week) { row in
          LineMark(x: .value("week", row.week), y: .value("held", row.heldPercent ?? 0))
            .foregroundStyle(TollColor.accent)
        }
        .chartXAxis(.hidden)
        .frame(height: ChartHeight.line)
        .audioGraph(Copy.Insights.weekOnWeek, labels: data.weekly.map(\.week), values: data.weekly.map { Double($0.heldPercent ?? 0) })
      }
      if let same = data.sameAppSameHour {
        Text(Copy.Insights.sameApp(same.count, app: Copy.Tags.display(same.tag), after: model.lateStartLabel))
          .tollText(.subhead)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private var peakCaption: String? {
    guard data.friendsByHour.reduce(0, +) >= model.minN,
      let peak = data.friendsByHour.indices.max(by: { data.friendsByHour[$0] < data.friendsByHour[$1] })
    else { return nil }
    return Copy.Insights.peakHour(ChartLabels.hour(peak))
  }

  private var changeCaption: String? {
    let held = data.weekly.compactMap(\.heldPercent)
    guard held.count >= 2, let last = held.last else { return nil }
    return Copy.Insights.friendsChange(last - held[held.count - 2])
  }
}

/// I-15…I-19. School aggregates only; nobody is ranked.
struct SchoolInsightsCards: View {
  let model: InsightsModel
  let data: SchoolInsights

  var body: some View {
    let name = data.school?.name ?? ""
    VStack(spacing: 16) {
      if let distribution = data.distribution {
        let mine = distribution.bins.first { $0.includesMe }
        let total = max(1, distribution.bins.reduce(0) { $0 + $1.count })
        ChartCard(
          title: Copy.Insights.distribution,
          caption: mine.map {
            Copy.Insights.schoolBin(from: $0.from, to: $0.to, percent: $0.count * 100 / total, school: name)
          }
        ) {
          BinBars(bins: distribution.bins.map { ($0.from, $0.to, $0.count, $0.includesMe) }, title: Copy.Insights.distribution)
        }
      }
      ChartCard(title: Copy.Insights.schoolVsYou, caption: Copy.Insights.asOf) {
        HStack {
          MetricPair(label: name, value: data.schoolHeldPercent.map(Copy.percent) ?? "—")
          MetricPair(label: Copy.Insights.me, value: data.myHeldPercent.map(Copy.percent) ?? "—")
        }
        Chart {
          ForEach(data.weekly, id: \.week) { row in
            LineMark(x: .value("week", row.week), y: .value("held", row.schoolHeldPercent ?? 0), series: .value("who", "school"))
              .foregroundStyle(TollColor.neutralBar)
            LineMark(x: .value("week", row.week), y: .value("held", row.myHeldPercent ?? 0), series: .value("who", "me"))
              .foregroundStyle(TollColor.accent)
          }
        }
        .chartXAxis(.hidden)
        .frame(height: ChartHeight.line)
        .audioGraph(Copy.Insights.schoolVsYou, labels: data.weekly.map(\.week), values: data.weekly.map { Double($0.schoolHeldPercent ?? 0) })
      }
      ChartCard(title: Copy.Insights.schoolByHour) {
        let myTotal = max(1, data.myByHour.reduce(0, +))
        HourBars(
          values: data.byHour, overlay: data.myByHour.map { Double($0) / Double(myTotal) },
          lateStart: model.app.config.insights.lateStart, resetHour: model.app.config.gate.dayResetHour,
          title: Copy.Insights.schoolByHour)
      }
      let shares = data.tagShare.sorted { $0.value > $1.value }
      ChartCard(
        title: Copy.Insights.whatSchoolBlocks,
        caption: shares.first.map { Copy.Insights.mostBlocked(Copy.Tags.display(Tag(rawValue: $0.key)), school: name) }
      ) {
        Chart(shares, id: \.key) { share in
          BarMark(x: .value("share", share.value), stacking: .normalized)
            .foregroundStyle(by: .value("app", Copy.Tags.display(Tag(rawValue: share.key))))
        }
        .frame(height: 44)
        .audioGraph(Copy.Insights.whatSchoolBlocks, labels: shares.map { Copy.Tags.display(Tag(rawValue: $0.key)) }, values: shares.map(\.value))
      }
    }
  }
}
