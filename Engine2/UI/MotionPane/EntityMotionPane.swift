//
//  EntityMotionPane.swift
//  Engine2
//
//  Created by Codex on 5/31/26.
//

import SwiftUI
import simd

@MainActor
struct EntityMotionPane: View {
    let simulation: SimulationRuntime

    var body: some View {
        TimelineView(.animation) { _ in
            let rows = EntityMotionRow.extract(from: simulation.world)

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
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                        }
                    }
                }
                .padding(14)
                .frame(width: 320, alignment: .leading)
                .glassEffect(
                    .regular.tint(.cyan.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Entity motion")
        }
    }
}

private struct EntityMotionRow: Identifiable, Equatable {
    let id: EntityID
    let position: SIMD3<Float>
    let speed: Float

    var locationText: String {
        "(\(Self.format(position.x)), \(Self.format(position.y)), \(Self.format(position.z)))"
    }

    var speedText: String {
        Self.format(speed)
    }

    static func extract(from world: World) -> [EntityMotionRow] {
        world.positionComponents.entities.compactMap { entity in
            guard let position = world.positionComponents[entity]?.position else {
                return nil
            }

            let velocity = world.motionComponents[entity]?.velocity ?? .zero

            return EntityMotionRow(
                id: entity,
                position: position,
                speed: simd.length(velocity)
            )
        }
    }

    private static func format(_ value: Float) -> String {
        String(format: "%.2f", value)
    }
}
