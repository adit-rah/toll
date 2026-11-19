import SwiftUI
import TollCore
import TollUI

struct SectionHeader: View {
  let title: String
  var action: (title: String, run: () -> Void)?

  init(_ title: String, action: (title: String, run: () -> Void)? = nil) {
    self.title = title
    self.action = action
  }

  var body: some View {
    HStack {
      Text(title)
        .font(TollFont.captionMedium)
        .foregroundStyle(TollColor.label2)
        .accessibilityAddTraits(.isHeader)
      Spacer()
      if let action {
        Button(action.title, action: action.run)
          .font(TollFont.subheadSemibold)
          .foregroundStyle(TollColor.accent)
      }
    }
  }
}

struct UnlockRow: View {
  let left: Int
  let open: () -> Void

  var body: some View {
    Card {
      CardRow(Copy.Home.unlocksLeft(left)) {
        IconTile("key.fill")
      } trailing: {
        if left > 0 {
          Button(Copy.Home.openOneApp, action: open).buttonStyle(.tollQuiet)
        }
      }
    }
  }
}

struct PausedCard: View {
  let price: String
  let open: () -> Void

  var body: some View {
    Button(action: open) {
      Card {
        CardRow(Copy.Home.turnBackOn, detail: Copy.Home.once(price)) {
          IconTile("moon.fill")
        } trailing: {
          Image(systemName: "chevron.right").foregroundStyle(TollColor.label3)
        }
      }
    }
    .buttonStyle(.plain)
  }
}

/// D37: a fact and the way to change it, never a warning.
struct LocationBanner: View {
  let fix: () -> Void

  var body: some View {
    Card {
      CardRow(Copy.Home.locationBannerTitle, detail: Copy.Home.locationBanner) {
        IconTile("location.slash", accent: false)
      } trailing: {
        Button(Copy.Home.fixInSettings, action: fix).buttonStyle(.tollQuiet)
      }
    }
  }
}

/// Tonight on a 6 pm → 10 am strip, with Now marked (the canvas).
struct TimelineStrip: View {
  let timeline: HomeSnapshot.Timeline
  private let labels = ["6 pm", "10 pm", "2 am", "6 am", "10 am"]

  var body: some View {
    VStack(spacing: 10) {
      GeometryReader { proxy in
        let width = proxy.size.width
        ZStack(alignment: .leading) {
          Capsule().fill(TollColor.surfaceRaised)
          Capsule()
            .fill(TollColor.accentSoft)
            .overlay(Capsule().stroke(TollColor.accent.opacity(0.5), lineWidth: 1))
            .frame(width: max(8, width * (timeline.end - timeline.start)))
            .offset(x: width * timeline.start)
          if let now = timeline.now {
            RoundedRectangle(cornerRadius: 1)
              .fill(TollColor.label)
              .frame(width: 2, height: 20)
              .offset(x: width * now - 1)
          }
        }
      }
      .frame(height: 20)
      HStack {
        ForEach(labels, id: \.self) { label in
          Text(label).frame(maxWidth: .infinity)
        }
      }
      .font(TollFont.micro)
      .foregroundStyle(TollColor.label2)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(timeline.label)
  }
}

struct WeekCard: View {
  let home: HomeSnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      StatTiles(home: home)
      if home.showsTrends {
        VStack(alignment: .leading, spacing: 6) {
          Text(Copy.Home.byNight).font(TollFont.micro).foregroundStyle(TollColor.label2)
          NightBars(bars: home.bars)
        }
      } else {
        Text(Copy.Home.trendsLater).font(TollFont.caption).foregroundStyle(TollColor.label2)
      }
    }
    .padding(.vertical, 18)
    .padding(.horizontal, TollSpacing.cardPadding)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      TollColor.surface, in: RoundedRectangle(cornerRadius: TollRadius.card, style: .continuous))
  }
}

/// Times the block stopped you, one bar per night; tonight in amber.
struct NightBars: View {
  let bars: [HomeSnapshot.Bar]

  var body: some View {
    let top = max(1, bars.map(\.count).max() ?? 1)
    HStack(alignment: .bottom, spacing: 8) {
      ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
        VStack(spacing: 4) {
          Text(bar.count > 0 ? "\(bar.count)" : " ")
            .font(TollFont.micro).monospacedDigit().foregroundStyle(TollColor.label2)
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(bar.isToday ? TollColor.accent : TollColor.fill)
            .frame(height: max(4, 64 * CGFloat(bar.count) / CGFloat(top)))
          Text(bar.day)
            .font(TollFont.micro)
            .foregroundStyle(bar.isToday ? TollColor.label : TollColor.label2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bar.day), \(bar.count)")
      }
    }
    .frame(height: 104, alignment: .bottom)
  }
}

struct BlockList: View {
  let rows: [HomeSnapshot.BlockRow]
  var open: ((BlockID) -> Void)?

  var body: some View {
    Card {
      ForEach(rows) { row in
        Button {
          open?(row.id)
        } label: {
          CardRow(row.name, detail: row.detail) {
            IconTile(BlockSymbol.name(row.kind), accent: row.trailingIsAccent)
          } trailing: {
            Text(row.trailing)
              .font(TollFont.captionMedium)
              .foregroundStyle(row.trailingIsAccent ? TollColor.accent : TollColor.label3)
          }
        }
        .buttonStyle(.plain)
        .disabled(open == nil)
      }
    }
  }
}

enum BlockSymbol {
  static func name(_ kind: Block.Kind) -> String {
    switch kind {
    case .sleep: "moon.fill"
    case .study: "book.fill"
    case .work: "briefcase.fill"
    case .gym: "figure.run"
    case .other: "square.grid.2x2.fill"
    }
  }
}
