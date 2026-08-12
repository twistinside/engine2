import SwiftUI

/// Shows one conserved mass budget as proportional named destinations.
struct LedgerBudgetBar: View {
    let title: String
    let values: [Double]
    let labels: [String]
    let colors: [Color]

    private let presentation = StarSystemPresentation()

    private var total: Double {
        values.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(presentation.number(total)) M⊕")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Canvas { context, size in
                guard total > 0 else {
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.gray.opacity(0.25)))
                    return
                }

                var originX = 0.0
                for index in values.indices {
                    let width = size.width * values[index] / total
                    let segment = CGRect(x: originX, y: 0, width: width, height: size.height)
                    context.fill(Path(segment), with: .color(colors[index]))
                    originX += width
                }
            }
            .frame(height: 14)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], alignment: .leading, spacing: 6) {
                ForEach(values.indices, id: \.self) { index in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colors[index])
                            .frame(width: 9, height: 9)
                        Text(labels[index])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 2)
                        Text(presentation.number(values[index]))
                            .font(.caption2.monospacedDigit())
                    }
                }
            }
        }
    }

    init(title: String, values: [Double], labels: [String], colors: [Color]) {
        precondition(
            values.count == labels.count && labels.count == colors.count,
            "A ledger budget requires one label and color for every value."
        )
        self.title = title
        self.values = values
        self.labels = labels
        self.colors = colors
    }
}
