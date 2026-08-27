import simd
import Testing
@testable import Engine2

struct SCameraInputTests {
    @Test func followedEntityPositionReplacesTheConfiguredFallbackTarget() {
        let followedEntity = EntityID(index: 42, generation: 3)
        let followedPosition = SIMD3<Double>(100, 50, 0)
        let target = followedPosition.singlePrecision
        var world = World()
        world.cameraFollowEntityID = followedEntity
        world.positionComponents.insert(
            CPosition(position: followedPosition),
            for: followedEntity
        )
        world.camera = Camera.lookingAt(
            target,
            from: target + SIMD3<Float>(0, 0, 500),
            up: SIMD3<Float>(0, 1, 0),
            projection: .standardPerspective
        )
        world.input.cameraOrbitDelta.x = .pi / 2
        var system = SCameraInput(
            target: .zero,
            minimumRadius: 250,
            maximumRadius: 2_500
        )

        system.update(world: &world, deltaTime: 1)

        #expect(world.camera.position.isApproximately(target + SIMD3<Float>(500, 0, 0)))
        let targetInViewSpace = world.camera.viewMatrix * SIMD4<Float>(target, 1)
        #expect(targetInViewSpace.x.isApproximately(0))
        #expect(targetInViewSpace.y.isApproximately(0))
        #expect(targetInViewSpace.z < 0)
    }

    @Test func orbitAndZoomDeriveFromAuthoritativeCameraState() {
        let target = SIMD3<Float>(1, 2, 3)
        let projection = Camera.Projection.orthographic(
            height: 12,
            near: 0.5,
            far: 200
        )
        var world = World()
        let cameraPosition = target + SIMD3<Float>(0, 4, 8)
        world.camera = Camera.lookingAt(
            target,
            from: cameraPosition,
            up: SIMD3<Float>(0, 1, 0),
            projection: projection
        )
        world.input.cameraOrbitDelta.x = .pi / 2
        world.input.cameraZoomDelta = 2
        var system = SCameraInput(
            target: target,
            minimumRadius: 2,
            maximumRadius: 10
        )

        system.update(world: &world, deltaTime: 1)

        let expectedPosition = target + SIMD3<Float>(6, 4, 0)

        #expect(world.camera.position.isApproximately(expectedPosition))
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

        world.input.cameraOrbitDelta.x = .pi / 2
        system.update(world: &world, deltaTime: 1)
        #expect(world.camera.position.isApproximately(SIMD3<Float>(8, 0, 0)))

        world.input.cameraOrbitDelta.x = -.pi
        system.update(world: &world, deltaTime: 1)
        #expect(world.camera.position.isApproximately(SIMD3<Float>(-8, 0, 0)))
    }

    @Test func miningOrbitPreservesHeightAndNondegeneratePlanarCameraAxes() {
        var world = World()
        world.camera = Camera.lookingAt(
            .zero,
            from: SIMD3<Float>(0, -500, 500),
            up: SIMD3<Float>(0, 0, 1),
            projection: .standardPerspective
        )
        world.input.cameraOrbitDelta.x = .pi / 2
        var system = SCameraInput(
            target: .zero,
            orbitAxis: SIMD3<Float>(0, 0, 1),
            minimumRadius: 250,
            maximumRadius: 2_500
        )

        system.update(world: &world, deltaTime: 1)

        #expect(
            world.camera.position.isApproximately(
                SIMD3<Float>(500, 0, 500),
                tolerance: 0.001
            )
        )
        let cameraRight = world.camera.rotation.act(SIMD3<Float>(1, 0, 0))
        let cameraUp = world.camera.rotation.act(SIMD3<Float>(0, 1, 0))
        #expect(simd_length(SIMD2<Float>(cameraRight.x, cameraRight.y)) > 0.99)
        #expect(simd_length(SIMD2<Float>(cameraUp.x, cameraUp.y)) > 0.5)
    }

    @Test func hugeZoomCommandsClampAndRepeatedBlockedInputIsANoOp() {
        var world = World()
        var system = SCameraInput(
            target: .zero,
            minimumRadius: 4,
            maximumRadius: 10
        )

        world.input.cameraZoomDelta = .greatestFiniteMagnitude
        system.update(world: &world, deltaTime: 1)
        #expect(world.camera.position.isApproximately(SIMD3<Float>(0, 0, 4)))

        let minimumCamera = world.camera
        system.update(world: &world, deltaTime: 1)
        #expect(world.camera == minimumCamera)

        world.input.cameraZoomDelta = -.greatestFiniteMagnitude
        system.update(world: &world, deltaTime: 1)
        #expect(world.camera.position.isApproximately(SIMD3<Float>(0, 0, 10)))

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

        world.input.cameraOrbitDelta.x = .nan
        world.input.cameraZoomDelta = .infinity
        system.update(world: &world, deltaTime: 1)
        #expect(world.camera == initialCamera)

        world.input.cameraOrbitDelta.x = -.infinity
        world.input.cameraZoomDelta = .nan
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
        world.input.cameraOrbitDelta.x = 1e20

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
