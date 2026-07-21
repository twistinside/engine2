/// Builds the example content's deterministic PBR material-comparison world.
///
/// Six ordinary balls share one mesh and form two roughness rows: warm
/// dielectrics above gold metals. They retain their normal movement and rotation
/// capabilities, but zero-valued seeds keep the reference scene quiescent while
/// it traverses the ordinary Simulation-to-Render presentation path.
struct BasicWorldBuilder: PWorldBuilder {
    func buildWorld() -> World {
        let world = World()

        _ = Ball(
            in: world,
            materialID: .warmDielectricSmooth,
            position: SIMD3<Float>(-1.75, 1.10, 0)
        )
        _ = Ball(
            in: world,
            materialID: .warmDielectric,
            position: SIMD3<Float>(0, 1.10, 0)
        )
        _ = Ball(
            in: world,
            materialID: .warmDielectricRough,
            position: SIMD3<Float>(1.75, 1.10, 0)
        )
        _ = Ball(
            in: world,
            materialID: .goldMetalSmooth,
            position: SIMD3<Float>(-1.75, -1.10, 0)
        )
        _ = Ball(
            in: world,
            materialID: .goldMetal,
            position: SIMD3<Float>(0, -1.10, 0)
        )
        _ = Ball(
            in: world,
            materialID: .goldMetalRough,
            position: SIMD3<Float>(1.75, -1.10, 0)
        )

        return world
    }
}
