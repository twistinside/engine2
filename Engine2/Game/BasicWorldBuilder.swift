//
//  WorldBuilder.swift
//  Engine2
//
//  Created by Codex on 3/17/26.
//

/// Minimal concrete builder used by the app and simple tests.
///
/// The default world starts with a few moving balls so the bootstrap path
/// exercises normal entity-to-component creation and renderer extraction.
struct BasicWorldBuilder: WorldBuilder {
    func buildWorld() -> World {
        let world = World()

        _ = Ball(
            in: world,
            position: SIMD3<Float>(-2.0, -1.0, 0),
            velocity: SIMD3<Float>(0.65, 0.45, 0),
            accelerationIntent: .accelerating(SIMD3<Float>(0.02, 0.01, 0))
        )
        _ = Ball(
            in: world,
            position: SIMD3<Float>(2.0, -1.0, 0),
            velocity: SIMD3<Float>(-0.25, 0.35, 0),
            accelerationIntent: .idle
        )
        _ = Ball(
            in: world,
            position: SIMD3<Float>(-1.5, 1.2, 0),
            velocity: SIMD3<Float>(0, 0, 0),
            accelerationIntent: .accelerating(SIMD3<Float>(0.02, -0.02, 0))
        )
        _ = Ball(
            in: world,
            position: SIMD3<Float>(1.7, 1.1, 0),
            velocity: SIMD3<Float>(-0.45, -0.45, 0),
            accelerationIntent: .accelerating(SIMD3<Float>(-0.02, -0.01, 0))
        )

        return world
    }
}
