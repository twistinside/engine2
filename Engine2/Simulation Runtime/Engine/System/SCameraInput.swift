//
//  SCameraInput.swift
//  Engine2
//
//  Created by Codex on 6/14/26.
//

import simd

/// Applies mapped camera input to the active perspective orbit camera.
struct SCameraInput: PSystem {
    var target: SIMD3<Float>
    var minimumRadius: Float
    var maximumRadius: Float
    var projection: Camera.Projection

    private var yaw: Float
    private var radius: Float

    init(
        target: SIMD3<Float> = .zero,
        initialYaw: Float = 0,
        initialRadius: Float = 8,
        minimumRadius: Float = 2,
        maximumRadius: Float = 30,
        projection: Camera.Projection = .perspective(
            verticalFieldOfView: .pi / 3,
            near: 0.1,
            far: 100
        )
    ) {
        self.target = target
        self.yaw = initialYaw
        self.radius = initialRadius
        self.minimumRadius = minimumRadius
        self.maximumRadius = maximumRadius
        self.projection = projection
    }

    mutating func update(world: inout World, deltaTime: Float) {
        yaw += world.input.actions.cameraOrbitDelta.x
        radius = min(
            maximumRadius,
            max(minimumRadius, radius - world.input.actions.cameraZoomDelta)
        )

        let cameraPosition = target + SIMD3<Float>(
            sinf(yaw) * radius,
            0,
            cosf(yaw) * radius
        )

        world.camera = Camera.lookingAt(
            target,
            from: cameraPosition,
            projection: projection
        )
    }
}
