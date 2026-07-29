import Engine2
import Engine2AssemblySupport
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
        "(\(format(position.x)), \(format(position.y)), \(format(position.z)))"
    }

    var speedText: String {
        format(speed)
    }

    static func extract(
        from snapshots: [EntityMotionSnapshot]
    ) -> [EntityMotionRow] {
        snapshots.map { snapshot in
            return EntityMotionRow(
                id: snapshot.id,
                position: snapshot.position,
                speed: simd.length(snapshot.velocity)
            )
        }
    }

    private func format(_ value: Float) -> String {
        String(format: "%.2f", value)
    }
}
