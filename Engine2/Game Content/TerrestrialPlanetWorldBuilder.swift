/// Builds the example content's single-planet orbital proof scene.
///
/// The scene uses an authored Blue Marble proof camera and one scaled
/// authoritative entity. Its layered appearance remains catalog data resolved
/// privately by Render.
struct TerrestrialPlanetWorldBuilder: PWorldBuilder {
    /// Distant, narrow-field camera that approximates the Apollo photograph.
    static let proofCamera = Camera(
        position: SIMD3<Float>(0, 0, 14),
        rotation: .identity,
        projection: .perspective(
            verticalFieldOfView: .pi * 23 / 180,
            near: 0.1,
            far: 100
        )
    )

    func buildWorld() -> World {
        let world = World()
        world.camera = Self.proofCamera
        _ = TerrestrialPlanet(in: world)
        return world
    }
}
