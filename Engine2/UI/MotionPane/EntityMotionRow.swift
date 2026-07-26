import Foundation
import simd

/// Display projection joining one entity's position with its current speed.
///
/// Rows are derived on demand from component stores and carry no authority back
/// into the simulation.
struct EntityMotionRow: Identifiable, Equatable {
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
