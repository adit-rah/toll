import SwiftUI
import TollCore
import TollData
import TollUI

/// The invite sheet (design §4.9): the code, a share link, one caption. The code is the one fact, so
/// it takes the middle; the action sits on the bottom edge, under the thumb, at any sheet height.
struct InviteSheet: View {
  let app: AppModel
  @State private var invite: Invite?
  @State private var failed = false
  @Environment(\.dynamicTypeSize) private var typeSize

  // Design §4.9 names the size; the code is a label, not text to read, so it does not scale.
  private static let codeSize: CGFloat = 44
  private static let codeTracking: CGFloat = 6

  var body: some View {
    GeometryReader { proxy in
      ScrollView {
        VStack(spacing: TollSpacing.groupGap) {
          code.frame(maxWidth: .infinity, maxHeight: .infinity)
          actions
        }
        .tollGutter()
        .padding(.top, TollSpacing.sectionGap)
        .padding(.bottom, TollSpacing.footerBottom)
        // Fills the sheet when there is room and scrolls when large text needs more than that.
        .frame(minHeight: proxy.size.height)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .presentationDetents(typeSize.isAccessibilitySize ? [.medium, .large] : [.medium])
    .presentationDragIndicator(.visible)
    .task { await load() }
  }

  // Known from `me` before the network answers, so the sheet never opens on a placeholder.
  private var shownCode: String? { invite?.code ?? app.me?.inviteCode }

  private var code: some View {
    VStack(spacing: TollSpacing.labelGap) {
      Text(Copy.Invite.yourCode).tollText(.caption)
      Text(verbatim: shownCode ?? " ")
        .font(.system(size: Self.codeSize, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .tracking(Self.codeTracking)
        // Tracking also trails the last character; without this the code sits left of centre.
        .padding(.leading, Self.codeTracking)
        .foregroundStyle(TollColor.label)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .textSelection(.enabled)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Copy.Invite.yourCode)
    .accessibilityValue(Text(verbatim: shownCode ?? "").speechSpellsOutCharacters())
  }

  private var actions: some View {
    VStack(spacing: 12) {
      if let invite, let url = URL(string: invite.url) {
        ShareLink(item: url, message: Text(Copy.Invite.message(invite.url))) {
          Text(Copy.Invite.share)
        }
        .buttonStyle(.tollPrimary)
      } else {
        // The button holds its place while the link loads, so nothing jumps when it arrives.
        Button(Copy.Invite.share) {}
          .buttonStyle(.tollPrimary)
          .disabled(true)
      }
      Text(failed ? Copy.Errors.offline : Copy.Invite.caption)
        .tollText(.caption)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func load() async {
    do {
      invite = try await app.deps.network.invite()
      failed = false
    } catch {
      failed = !Task.isCancelled
    }
  }
}
