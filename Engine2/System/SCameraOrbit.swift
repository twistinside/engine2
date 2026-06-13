//
//  SCameraOrbit.swift
//  Engine2
//
//  Created by Codex on 6/13/26.
//

import Foundation
import simd

/// Orbits the active camera around the world origin for simple scene inspection.
struct SCameraOrbit: System {
    var angularSpeed: Float
    var radius: Float
    var target: SIMD3<Float>
    var projection: Camera.Projection
    private var angle: Float

    init(
        angularSpeed: Float = .pi / 10,
        radius: Float = 8,
        target: SIMD3<Float> = .zero,
        projection: Camera.Projection = .perspective(
            verticalFieldOfView: .pi / 3,
            near: 0.1,
            far: 100
        ),
        initialAngle: Float = 0
    ) {
        self.angularSpeed = angularSpeed
        self.radius = radius
        self.target = target
        self.projection = projection
        self.angle = initialAngle
    }

    mutating func update(world: inout World, deltaTime: Float) {
        angle += angularSpeed * deltaTime
        let cameraPosition = target + SIMD3<Float>(
            sinf(angle) * radius,
            0,
            cosf(angle) * radius
        )

        world.camera = Camera.lookingAt(
            target,
            from: cameraPosition,
            projection: projection
        )
    }
}
