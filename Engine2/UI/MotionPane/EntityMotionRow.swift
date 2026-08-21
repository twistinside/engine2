import Foundation
import simd

/// Display projection joining one entity's position with its current speed.
///
/// Rows are derived on demand from component stores and carry no authority back
/// into the simulation.
struct EntityMotionRow: Identifiable, Equatable {
    let id: EntityID
    let position: SIMD3<Double>
    let speed: Double

    var locationText: String {
        "(\(format(position.x)), \(format(position.y)), \(format(position.z)))"
    }

    var speedText: String {
        format(speed)
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

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
