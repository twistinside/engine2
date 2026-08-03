/// Builds the deterministic high-cardinality world used by the headless host.
///
/// Every entity is an ordinary renderable `Ball` with nonzero translational and
/// angular motion. The executable therefore exercises the complete production
/// system schedule and Simulation-owned presentation publication without
/// constructing an Input Runtime, Render Runtime, or GPU resources.
struct HeadlessSimulationWorldBuilder: PWorldBuilder {
    private static let entitiesPerRow = 1_000

    let entityCount: Int

    init(entityCount: Int) {
        precondition(entityCount > 0, "The headless host requires at least one entity.")
        self.entityCount = entityCount
    }

    func buildWorld() -> World {
        let world = World()
        let velocity = SIMD3<Float>(3, 2, 1)
        let accelerationIntent = CMotion.AccelerationIntent.accelerating(
            SIMD3<Float>(0.25, 0.5, 0.75)
        )
        let angularVelocity = SIMD3<Float>(0.2, 0.3, 0.4)

        for entityIndex in 0..<entityCount {
            _ = Ball(
                in: world,
                materialID: .warmDielectric,
                position: initialPosition(forEntityAt: entityIndex),
                velocity: velocity,
                accelerationIntent: accelerationIntent,
                angularVelocity: angularVelocity
            )
        }

        return world
    }

    /// Returns the deterministic spawn position for one headless entity.
    func initialPosition(forEntityAt entityIndex: Int) -> SIMD3<Float> {
        precondition(
            (0..<entityCount).contains(entityIndex),
            "The headless entity index must identify a configured entity."
        )
        return SIMD3<Float>(
            Float(entityIndex % Self.entitiesPerRow),
            Float(entityIndex / Self.entitiesPerRow),
            0
        )
    }
}
