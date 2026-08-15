import SwiftUI

/// Encodes one orthogonal body classification without collapsing it into a single planet kind.
struct ClassificationTag: View {
    let label: String
    let helpText: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(label, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
            .background {
                HoverHelpSurface(text: helpText)
            }
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.24), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(.interaction, Capsule())
            .accessibilityHint(helpText)
    }
}
