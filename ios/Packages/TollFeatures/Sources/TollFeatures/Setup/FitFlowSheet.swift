import SwiftUI
import TollCore
import TollUI

/// One-time flow #1, "Fit Dusk to your sleep" (#144), for people set up before it: onboarding's
/// steps 2 to 4 in a sheet, starting from their own night and gap. Save answers it; Cancel or a
/// swipe leaves it shown, so it comes back another day; the card's "Not now" counts toward
/// putting it off for good (`Flows`).
struct FitFlowSheet: View {
  let app: AppModel
  let close: () -> Void
  @State private var draft: FitDraft
  @State private var path: [Step]

  enum Step: Hashable {
    case sleep, around
  }

  init(
    app: AppModel, path: [Step] = [], draft: FitDraft? = nil, close: @escaping () -> Void
  ) {
    self.app = app
    self.close = close
    _draft = State(initialValue: draft ?? .existing(app.state, config: app.config))
    _path = State(initialValue: path)
  }

  var body: some View {
    NavigationStack(path: $path) {
      FitChoice(
        draft: draft,
        useHealth: {
          Task {
            draft.reading = true
            draft.health = true
            draft.found(await app.readSleep())
            draft.reading = false
            path.append(.sleep)
          }
        },
        setMyself: {
          draft.health = false
          draft.found(nil)
          path.append(.sleep)
        }
      )
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(Copy.Fit.cancel, action: close)
        }
      }
      .navigationDestination(for: Step.self) { step in
        switch step {
        case .sleep:
          SleepTimesStep(draft: draft) { path.append(.around) }
        case .around:
          AroundStep(draft: draft, action: Copy.Fit.save) {
            app.flow(Flows.fitSleep.id, .answered, fit: draft.fit)
            close()
          }
        }
      }
    }
    // Cancel is wider than a back button: the bar keeps clear of it.
    .setupProgress(step: path.count + 1, of: 3, inset: 72)
    .tint(TollColor.accent)
  }
}
