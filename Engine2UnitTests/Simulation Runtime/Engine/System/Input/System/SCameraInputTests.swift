import simd
import Testing
@testable import Engine2

struct SCameraInputTests {
    @Test func orbitAndZoomDeriveFromAuthoritativeCameraState() {
        let target = SIMD3<Float>(1, 2, 3)
        let projection = Camera.Projection.orthographic(
            height: 12,
            near: 0.5,
            far: 200
        )
        var world = World()
        world.camera = Camera.lookingAt(
            target,
            from: target + SIMD3<Float>(0, 4, 8),
            up: SIMD3<Float>(0, 1, 0),
            projection: projection
        )
        world.input.actions.cameraOrbitYawDelta = .pi / 2
        world.input.actions.cameraZoomDelta = 2
        var system = SCameraInput(
            target: target,
            minimumRadius: 2,
            maximumRadius: 10
        )

        system.update(world: &world, deltaTime: 1)

        #expect(
            world.camera.position.isApproximately(
                target + SIMD3<Float>(6, 4, 0)
            )
        )
        #expect(world.camera.projection == projection)

        let targetInViewSpace = world.camera.viewMatrix * SIMD4<Float>(target, 1)
        #expect(targetInViewSpace.x.isApproximately(0))
        #expect(targetInViewSpace.y.isApproximately(0))
        #expect(targetInViewSpace.z < 0)
    }

    @Test func positiveAndNegativeOrbitCommandsAccumulateFromCurrentCamera() {
        var world = World()
        var system = SCameraInput(
            target: .zero,
            minimumRadius: 2,
            maximumRadius: 30
        )

        world.input.actions.cameraOrbitYawDelta = .pi / 2
        system.update(world: &world, deltaTime: 1)
        #expect(
            world.camera.position.isApproximately(SIMD3<Float>(8, 0, 0))
        )

        world.input.actions.cameraOrbitYawDelta = -.pi
        system.update(world: &world, deltaTime: 1)
        #expect(
            world.camera.position.isApproximately(SIMD3<Float>(-8, 0, 0))
        )
    }

    @Test func hugeZoomCommandsClampAndRepeatedBlockedInputIsANoOp() {
        var world = World()
        var system = SCameraInput(
            target: .zero,
            minimumRadius: 4,
            maximumRadius: 10
        )

        world.input.actions.cameraZoomDelta = .greatestFiniteMagnitude
        system.update(world: &world, deltaTime: 1)
        #expect(
            world.camera.position.isApproximately(SIMD3<Float>(0, 0, 4))
        )

        let minimumCamera = world.camera
        system.update(world: &world, deltaTime: 1)
        #expect(world.camera == minimumCamera)

        world.input.actions.cameraZoomDelta = -.greatestFiniteMagnitude
        system.update(world: &world, deltaTime: 1)
        #expect(
            world.camera.position.isApproximately(SIMD3<Float>(0, 0, 10))
        )

        let maximumCamera = world.camera
        system.update(world: &world, deltaTime: 1)
        #expect(world.camera == maximumCamera)
    }

    @Test func zeroAndNonfiniteCommandsLeaveCameraExactlyUnchanged() {
        var world = World()
        let initialCamera = world.camera
        var system = SCameraInput(
            target: .zero,
            minimumRadius: 2,
            maximumRadius: 30
        )

        system.update(world: &world, deltaTime: 1)
        #expect(world.camera == initialCamera)

        world.input.actions.cameraOrbitYawDelta = .nan
        world.input.actions.cameraZoomDelta = .infinity
        system.update(world: &world, deltaTime: 1)
        #expect(world.camera == initialCamera)

        world.input.actions.cameraOrbitYawDelta = -.infinity
        world.input.actions.cameraZoomDelta = .nan
        system.update(world: &world, deltaTime: 1)
        #expect(world.camera == initialCamera)
    }

    @Test func hugeFiniteOrbitRemainsFiniteAndKeepsRadius() {
        var world = World()
        let initialCamera = world.camera
        var system = SCameraInput(
            target: .zero,
            minimumRadius: 2,
            maximumRadius: 30
        )
        world.input.actions.cameraOrbitYawDelta = 1e20

        system.update(world: &world, deltaTime: 1)

        #expect(world.camera != initialCamera)
        #expect(world.camera.supportsViewTransform)
        #expect(hypotf(world.camera.position.x, world.camera.position.z)
            .isApproximately(8))
    }
}

private extension Float {
    func isApproximately(_ other: Float, tolerance: Float = 0.0001) -> Bool {
        abs(self - other) <= tolerance
    }
}

private extension SIMD3 where Scalar == Float {
    func isApproximately(_ other: SIMD3<Float>, tolerance: Float = 0.0001) -> Bool {
        abs(x - other.x) <= tolerance
            && abs(y - other.y) <= tolerance
            && abs(z - other.z) <= tolerance
    }
}
