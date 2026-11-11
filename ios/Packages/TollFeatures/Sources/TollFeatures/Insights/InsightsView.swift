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
        if let model { content(model) }
      }
      .background(TollColor.bgGrouped)
      .navigationTitle(Copy.Insights.title)
      .navigationBarTitleDisplayMode(.inline)
      .refreshable { await model?.refresh() }
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
    // Signing in or out, or joining a school, changes what the server will answer.
    .onChange(of: app.me?.id) { Task { await model?.refresh() } }
    .onChange(of: app.me?.school) { Task { await model?.refresh() } }
  }

  /// A lazy stack: only the cards on screen build their charts, on arrival and on every segment
  /// switch. The picker shares the cards' gutter so its edges line up with theirs.
  private func content(_ model: InsightsModel) -> some View {
    @Bindable var bound = model
    return LazyVStack(spacing: TollSpacing.grid * 2) {
      Picker(Copy.Insights.title, selection: $bound.segment) {
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
    .padding(.top, TollSpacing.grid)
    .padding(.bottom, TollSpacing.sectionGap)
    .tollGutter()
    .animation(Motion.stateChange, value: model.segment)
  }

  @ViewBuilder
  private func friends(_ model: InsightsModel) -> some View {
    if !app.isSignedIn {
      EmptyState(Copy.People.signInToAdd, actionTitle: Copy.People.signIn) { app.showsSignInSheet = true }
    } else if let data = model.friends {
      if data.people.count > 1 {
        FriendsInsightsCards(model: model, data: data)
      } else {
        EmptyState(Copy.Insights.noFriends, actionTitle: Copy.Home.sendInvite) { inviteShown = true }
      }
    } else if model.friendsState == .failed {
      EmptyState(Copy.Errors.generic)
    }
  }

  @ViewBuilder
  private func school(_ model: InsightsModel) -> some View {
    if !app.isSignedIn {
      EmptyState(Copy.Insights.notVerified, actionTitle: Copy.People.signIn) { app.showsSignInSheet = true }
    } else if let data = model.school, data.enough {
      SchoolInsightsCards(model: model, data: data)
    } else if app.me?.school == nil && model.school?.school == nil {
      // The one field that fixes it, under the line that says why (N-17).
      VStack(spacing: 0) {
        EmptyState(Copy.Insights.notVerified)
        FindFriendsView(app: app, isSetup: false, parts: [.school], showsHeaders: false)
      }
    } else if model.school != nil {
      EmptyState(Copy.People.schoolBelowMinimum)
    } else if model.schoolState == .failed {
      EmptyState(Copy.Errors.generic)
    }
  }
}
