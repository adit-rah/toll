import SwiftUI
import TollCore
import TollUI

/// One-time flow #2, personal timing (#171, D65), from its card in Tonight's band: what it does,
/// what it never does, and where it's turned off, each led by its tile, as the setup sheets draw
/// them. "Turn on" and "Keep my own time" both answer it for good; Cancel or a swipe leaves it
/// offered, so it comes back another day; the card's "Not now" counts toward putting it off
/// (`Flows`).
struct TimingOfferSheet: View {
  let app: AppModel
  let close: () -> Void

  var body: some View {
    NavigationStack {
      TimingOffer(config: app.config) {
        app.answerTiming(true)
        close()
      } keep: {
        app.answerTiming(false)
        close()
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(Copy.Fit.cancel, action: close)
        }
      }
    }
    .tint(TollColor.accent)
  }
}

/// The offer's page. Its numbers come from the config, so the words promise what the rules keep.
struct TimingOffer: View {
  let config: TollConfig
  let turnOn: () -> Void
  let keep: () -> Void

  var body: some View {
    SetupPage(title: Copy.Timing.title, subtitle: Copy.Timing.line, endsWithLink: true) {
      Card {
        row(Copy.Timing.moves(config.timing.mostMinutes), Copy.Timing.movesDetail, .timing)
        row(Copy.Timing.wake, Copy.Timing.wakeDetail, .sun)
        row(Copy.Timing.limits(config.gap.manualMax), Copy.Timing.limitsDetail, .beforeBed)
        row(Copy.Timing.off, Copy.Timing.offDetail, .settings)
      }
      .padding(.top, 24)
    } actions: {
      PrimaryButton(Copy.Timing.turnOn, action: turnOn)
      QuietButton(Copy.Timing.keep, action: keep)
    }
  }

  /// What it does leads in amber; what it never does and where it's turned off stay grey.
  private func row(_ title: String, _ detail: String, _ symbol: TollSymbol) -> some View {
    CardRow(title, detail: detail, size: .list) {
      IconTile(symbol, accent: symbol == .timing)
    }
    .accessibilityElement(children: .combine)
  }
}
