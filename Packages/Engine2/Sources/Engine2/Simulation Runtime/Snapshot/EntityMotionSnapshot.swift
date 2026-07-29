import simd

/// Immutable diagnostic motion facts for one entity in the current World.
///
/// The value exposes no component-store access or mutation capability. A
/// Simulation Runtime derives a fresh collection when tooling requests its
/// diagnostic projection.
public nonisolated struct EntityMotionSnapshot: Equatable, Sendable {
    public let id: EntityID
    public let position: SIMD3<Float>
    public let velocity: SIMD3<Float>

    public init(
        id: EntityID,
        position: SIMD3<Float>,
        velocity: SIMD3<Float>
    ) {
        self.id = id
        self.position = position
        self.velocity = velocity
    }
}
