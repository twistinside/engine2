//
//  CollisionWorldBuilder.swift
//  Engine2
//
//  Created by Codex on 7/15/26.
//

/// Visual test world containing two isolated pairs of approaching unit spheres.
///
/// Both pairs touch after one second, exchange their normal velocities, and
/// move apart. To run the demo, construct the app's content with
/// `BasicGameContent.collisionDemo`.
struct CollisionWorldBuilder: PWorldBuilder {
    func buildWorld() -> World {
        let world = World()
        world.camera = Camera(
            position: SIMD3<Float>(0, 0, 8),
            orthographicHeight: 8
        )

        // Slower lower pair.
        _ = Ball(
            in: world,
            position: SIMD3<Float>(-3, -1.5, 0),
            velocity: SIMD3<Float>(2, 0, 0)
        )
        _ = Ball(
            in: world,
            position: SIMD3<Float>(3, -1.5, 0),
            velocity: SIMD3<Float>(-2, 0, 0)
        )

        // Faster upper pair reaches contact at the same time.
        _ = Ball(
            in: world,
            position: SIMD3<Float>(-4, 1.5, 0),
            velocity: SIMD3<Float>(3, 0, 0)
        )
        _ = Ball(
            in: world,
            position: SIMD3<Float>(4, 1.5, 0),
            velocity: SIMD3<Float>(-3, 0, 0)
        )

        return world
    }
}
