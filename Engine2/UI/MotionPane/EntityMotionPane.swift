import SwiftUI

/// Debug overlay that presents a read-only projection of live ECS motion rows.
///
/// The pane extracts lightweight `EntityMotionRow` values for display and does
/// not turn entity facades into a simulation iteration path.
struct EntityMotionPane: View {
    let simulation: SimulationRuntime

    var body: some View {
        TimelineView(.animation) { _ in
            let rows = EntityMotionRow.extract(from: simulation.world)
            let rowShape = RoundedRectangle(cornerRadius: 10, style: .continuous)
            let paneShape = RoundedRectangle(cornerRadius: 18, style: .continuous)

            GlassEffectContainer(spacing: 8) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Entities")
                                .font(.headline)

                            Text("Live ECS motion")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(rows.count)")
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .contentTransition(.numericText())
                    }

                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            Text("ID")
                                .frame(width: 34, alignment: .leading)
                            Text("Location")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Speed")
                                .frame(width: 58, alignment: .trailing)
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)

                        ForEach(rows) { row in
                            HStack(spacing: 10) {
                                Text("#\(row.id.index)")
                                    .frame(width: 34, alignment: .leading)
                                    .foregroundStyle(.secondary)

                                Text(row.locationText)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(row.speedText)
                                    .frame(width: 58, alignment: .trailing)
                                    .foregroundStyle(.primary)
                                    .contentTransition(.numericText())
                            }
                            .font(.caption.monospacedDigit())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .glassEffect(
                                .clear.interactive(),
                                in: rowShape
                            )
                        }
                    }
                }
                .padding(14)
                .frame(width: 320, alignment: .leading)
                .glassEffect(
                    .regular.tint(.cyan.opacity(0.08)),
                    in: paneShape
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Entity motion")
        }
    }
}
