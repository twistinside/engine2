//
//  SCameraInputTests.swift
//  Engine2Tests
//
//  Created by Codex on 6/14/26.
//

import simd
import Testing
@testable import Engine2

struct SCameraInputTests {
    @Test func dragOrbitsCameraAroundYAxisAndLooksAtOrigin() async throws {
        var world = World()
        var system = SCameraInput(initialYaw: 0, initialRadius: 8)

        world.input.actions.cameraOrbitDelta = SIMD2<Float>(.pi / 2, 0)
        system.update(world: &world, deltaTime: 1)

        #expect(world.camera.position.isApproximately(SIMD3<Float>(8, 0, 0)))

        let originInViewSpace = world.camera.viewMatrix * SIMD4<Float>(0, 0, 0, 1)
        #expect(originInViewSpace.x.isApproximately(0))
        #expect(originInViewSpace.y.isApproximately(0))
        #expect(originInViewSpace.z.isApproximately(-8))
    }

    @Test func scrollZoomChangesRadiusAndClamps() async throws {
        var world = World()
        var system = SCameraInput(
            initialYaw: 0,
            initialRadius: 8,
            minimumRadius: 4,
            maximumRadius: 10
        )

        world.input.actions.cameraZoomDelta = 20
        system.update(world: &world, deltaTime: 1)
        #expect(world.camera.position.isApproximately(SIMD3<Float>(0, 0, 4)))

        world.input.actions.cameraZoomDelta = -20
        system.update(world: &world, deltaTime: 1)
        #expect(world.camera.position.isApproximately(SIMD3<Float>(0, 0, 10)))
    }
}

private extension Float {
    func isApproximately(_ other: Float, tolerance: Float = 0.0001) -> Bool {
        abs(self - other) <= tolerance
    }
}

private extension SIMD3 where Scalar == Float {
    func isApproximately(_ other: SIMD3<Float>, tolerance: Float = 0.0001) -> Bool {
        abs(x - other.x) <= tolerance &&
        abs(y - other.y) <= tolerance &&
        abs(z - other.z) <= tolerance
    }
}
