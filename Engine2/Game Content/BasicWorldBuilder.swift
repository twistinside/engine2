/// Builds the example content's deterministic PBR material-comparison world.
///
/// Six ordinary balls share one mesh and form two roughness rows: warm
/// dielectrics above gold metals. They retain their normal movement and rotation
/// capabilities, but zero-valued seeds keep the reference scene quiescent while
/// it traverses the ordinary Simulation-to-Render presentation path.
struct BasicWorldBuilder: PWorldBuilder {
    func buildWorld() -> World {
        let world = World()
        world.camera = .standard

        let warmDielectricSmoothPosition = SIMD3<Float>(-1.75, 1.10, 0)
        _ = Ball(
            in: world,
            materialID: .warmDielectricSmooth,
            position: warmDielectricSmoothPosition
        )

        let warmDielectricPosition = SIMD3<Float>(0, 1.10, 0)
        _ = Ball(
            in: world,
            materialID: .warmDielectric,
            position: warmDielectricPosition
        )

        let warmDielectricRoughPosition = SIMD3<Float>(1.75, 1.10, 0)
        _ = Ball(
            in: world,
            materialID: .warmDielectricRough,
            position: warmDielectricRoughPosition
        )

        let goldMetalSmoothPosition = SIMD3<Float>(-1.75, -1.10, 0)
        _ = Ball(
            in: world,
            materialID: .goldMetalSmooth,
            position: goldMetalSmoothPosition
        )

        let goldMetalPosition = SIMD3<Float>(0, -1.10, 0)
        _ = Ball(
            in: world,
            materialID: .goldMetal,
            position: goldMetalPosition
        )

        let goldMetalRoughPosition = SIMD3<Float>(1.75, -1.10, 0)
        _ = Ball(
            in: world,
            materialID: .goldMetalRough,
            position: goldMetalRoughPosition
        )

        return world
    }
}
