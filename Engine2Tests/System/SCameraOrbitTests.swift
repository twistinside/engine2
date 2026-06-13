//
//  SCameraOrbitTests.swift
//  Engine2Tests
//
//  Created by Codex on 6/13/26.
//

import simd
import Testing
@testable import Engine2

struct SCameraOrbitTests {
    @Test func orbitsCameraAroundYAxisAndLooksAtOrigin() async throws {
        var world = World()
        var system = SCameraOrbit(angularSpeed: .pi, radius: 8, initialAngle: 0)

        system.update(world: &world, deltaTime: 0.5)

        #expect(world.camera.position.isApproximately(SIMD3<Float>(8, 0, 0)))
        #expect(world.camera.projection == .perspective(verticalFieldOfView: .pi / 3, near: 0.1, far: 100))

        let originInViewSpace = world.camera.viewMatrix * SIMD4<Float>(0, 0, 0, 1)
        #expect(originInViewSpace.x.isApproximately(0))
        #expect(originInViewSpace.y.isApproximately(0))
        #expect(originInViewSpace.z.isApproximately(-8))
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
