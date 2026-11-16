import SwiftUI

/// One of the three facts under Home's hero (design §3.2): an uppercase `micro` label over a `number`
/// value, centred in an equal-width column.
public struct FactColumn<Value: View>: View {
  let label: String
  let value: Value

  public init(_ label: String, @ViewBuilder value: () -> Value) {
    self.label = label
    self.value = value()
  }

  public var body: some View {
    VStack(spacing: 4) {
      Text(label)
        .textCase(.uppercase)
        .font(TollFont.micro)
        .tracking(0.6)
        // `label2`, not the `micro` tier's `label3`: these name the numbers and must read at 4.5:1.
        .foregroundStyle(TollColor.label2)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      value
        .font(TollFont.number)
        .foregroundStyle(TollColor.label)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
  }
}
