import PhotosUI
import SwiftUI
import TollCore
import TollUI
import UIKit

/// The progress bar and the title at the same position on every step (design §4.3 layout rule). The
/// bar and the footer stay put; what is between them scrolls only when it has to (a 4.7" screen, large
/// text, the keyboard), so no step can push its button off the screen.
struct SetupScaffold<Content: View, Footer: View>: View {
  let app: AppModel
  let step: Int
  let title: String
  var background: Color = TollColor.bg
  @ViewBuilder let content: () -> Content
  @ViewBuilder let footer: () -> Footer

  var body: some View {
    VStack(spacing: 0) {
      ProgressSegments(count: app.setupSteps, current: min(step, app.setupSteps - 1))
        .frame(height: TollSpacing.barHeight)
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          ScreenTitle(title)
          content().padding(.top, TollSpacing.titleGap)
        }
        .padding(.bottom, TollSpacing.groupGap)
      }
      .scrollBounceBehavior(.basedOnSize)
      .scrollIndicators(.hidden)
      .scrollDismissesKeyboard(.interactively)
      footer().padding(.bottom, TollSpacing.footerBottom)
    }
    .tollGutter()
    .background(background)
  }
}

/// Set up 1 · You (flows §3).
struct YouView: View {
  let app: AppModel
  @State private var model: YouModel?
  @State private var photoItem: PhotosPickerItem?

  var body: some View {
    ZStack {
      if let model {
        @Bindable var bound = model
        SetupScaffold(app: app, step: 0, title: Copy.You.title) {
          VStack(alignment: .leading, spacing: 0) {
            PhotosPicker(selection: $photoItem, matching: .images) {
              ZStack(alignment: .bottomTrailing) {
                if let data = model.photo, let image = UIImage(data: data) {
                  Image(uiImage: image).resizable().scaledToFill().frame(width: 96, height: 96).clipShape(Circle())
                } else {
                  Avatar(name: model.name.isEmpty ? "?" : model.name, handle: model.handle, size: .profile)
                }
                Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(TollColor.accent)
                  .background(Circle().fill(TollColor.bg))
              }
            }
            .accessibilityLabel(Copy.You.addPhoto)
            .frame(maxWidth: .infinity)
            fieldLabel(Copy.You.name).padding(.top, TollSpacing.titleGap)
            FilledField(Copy.You.name, text: $bound.name)
              .textContentType(.name)
              .overlay(
                RoundedRectangle(cornerRadius: TollRadius.field, style: .continuous)
                  .strokeBorder(TollColor.level3, lineWidth: model.nameRinged ? 2 : 0))
            fieldLabel(Copy.You.handle).padding(.top, 20)
            FilledField(Copy.You.handle, text: $bound.handle) { handleStatus(model) }
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
            handleNote(model)
            Text(Copy.You.note).tollText(.caption).padding(.top, 12)
            if let error = model.error {
              Text(error).tollText(.subhead).padding(.top, 12)
            }
          }
        } footer: {
          PrimaryButton(Copy.You.continue) { Task { await model.save() } }
            .disabled(model.isSaving || model.handleState != .available && model.handleState != .unknown)
        }
      }
    }
    .task {
      if model == nil {
        model = YouModel(app: app)
        await model?.load()
      }
    }
    .onChange(of: photoItem) { _, item in
      Task { if let data = try? await item?.loadTransferable(type: Data.self) { model?.setPhoto(data) } }
    }
  }

  private func fieldLabel(_ text: String) -> some View {
    Text(text).tollText(.caption).padding(.bottom, 6).accessibilityHidden(true)
  }

  @ViewBuilder
  private func handleStatus(_ model: YouModel) -> some View {
    if model.handleState == .available {
      // Not `tollText`: its own colour sits closer to the text and would win over the level colour.
      Label(Copy.You.available, systemImage: "checkmark")
        .font(TollFont.captionMedium)
        .foregroundStyle(TollColor.level1)
        .transition(.opacity)
    } else if case .taken = model.handleState {
      Text(Copy.You.taken).tollText(.caption)
    }
  }

  @ViewBuilder
  private func handleNote(_ model: YouModel) -> some View {
    switch model.handleState {
    case .invalid:
      Text(Copy.You.invalidHandle).tollText(.caption).padding(.top, TollSpacing.labelGap)
    case .taken(let suggestions) where !suggestions.isEmpty:
      HStack {
        ForEach(suggestions, id: \.self) { s in ChoiceChip(s, isSelected: false) { model.handle = s } }
      }
      .padding(.top, TollSpacing.labelGap)
    default: EmptyView()
    }
  }
}

/// Set up 2 · Permissions (flows §4). There is no skip: Toll cannot work without Screen Time.
struct PermissionsView: View {
  let app: AppModel
  @State private var model: PermissionsModel?
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ZStack {
      if let model {
        SetupScaffold(app: app, step: app.setupSteps == 4 ? 1 : 0, title: Copy.Permissions.title) {
          VStack(alignment: .leading, spacing: 20) {
            row(icon: "hourglass", title: Copy.Permissions.screenTime, detail: Copy.Permissions.screenTimeDetail,
                trailing: model.phase == .ready ? nil : Copy.Permissions.denied, denied: model.phase != .ready)
            row(icon: "bell", title: Copy.Permissions.notifications, detail: Copy.Permissions.notificationsDetail,
                trailing: model.notificationsAllowed == true ? Copy.Permissions.allowed : nil, denied: false)
            if model.phase != .ready { Text(Copy.Permissions.deniedLine).tollText(.subhead) }
          }
        } footer: {
          PrimaryButton(model.phase == .ready ? Copy.Permissions.allow : Copy.Permissions.tryAgain) {
            Task { await model.allow() }
          }
          .disabled(model.isWorking)
        }
      }
    }
    .task { if model == nil { model = PermissionsModel(app: app) } }
    .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model?.recheck() } } }
  }

  private func row(icon: String, title: String, detail: String, trailing: String?, denied: Bool) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon).font(.title3).foregroundStyle(TollColor.label2)
        .frame(width: 44, height: 44)
        .background(
          TollColor.surfaceRaised, in: RoundedRectangle(cornerRadius: TollRadius.rowInCard, style: .continuous)
        )
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(title).tollText(.headline)
          Spacer()
          if let trailing {
            Text(trailing).font(TollFont.subhead).foregroundStyle(denied ? TollColor.level3 : TollColor.label2)
          }
        }
        Text(detail).tollText(.subhead)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
