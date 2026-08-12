import SwiftUI

/// Displays one labeled generated fact with a stable width and optional context.
struct MetricTile: View {
    let label: String
    let value: String
    let detail: String?
    let systemImage: String?
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.callout)
                    .foregroundStyle(tint)
                    .frame(width: 18, height: 18)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    init(
        _ label: String,
        value: String,
        detail: String? = nil,
        systemImage: String? = nil,
        tint: Color = .cyan
    ) {
        self.label = label
        self.value = value
        self.detail = detail
        self.systemImage = systemImage
        self.tint = tint
    }
}
