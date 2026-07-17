import SwiftUI

/// Header for the fixed-step input history, including its retained entry count.
struct InputHistoryHeader: View {
    let entryCount: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Input")
                    .font(.headline)

                Text("Fixed-step history")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entryCount, format: .number)
                .font(.title3.monospacedDigit().weight(.semibold))
                .contentTransition(.numericText())
        }
    }
}
