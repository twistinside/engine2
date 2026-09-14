import Testing
import simd
@testable import Engine2

struct CameraFollowSystemTests {
    @Test func pendingRemovalTargetDoesNotMoveTheCamera() {
        var world = World()
        let target = Entity(in: world, from: .empty).id
        let originalCamera = world.camera
        world.cameraFollowEntityID = target
        world.previousPositionComponents.insert(PreviousPositionComponent(position: .zero), for: target)
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(30, 40, 0)), for: target)
        #expect(world.entity(for: target)?.markForRemoval() == true)

        var system = CameraFollowSystem()
        system.update(world: &world, deltaTime: 1)

        #expect(world.camera.position == originalCamera.position)
        #expect(world.camera.rotation.vector == originalCamera.rotation.vector)
        #expect(world.camera.projection == originalCamera.projection)
        #expect(world.cameraFollowEntityID == target)
        #expect(world.positionComponents[target]?.position == SIMD3<Double>(30, 40, 0))
    }

    @Test func translatesCameraByTargetDisplacementWithoutChangingViewPolicy() {
        var world = World()
        let skiff = Entity(in: world, from: .empty).id
        let rotation = simd_quatf(angle: 0.4, axis: simd_normalize(SIMD3<Float>(1, 1, 0)))
        let projection = Camera.Projection.perspective(verticalFieldOfView: .pi / 3, near: 1, far: 10_000)
        world.camera = Camera(
            position: SIMD3<Float>(10, 20, 500),
            rotation: rotation,
            projection: projection
        )
        world.cameraFollowEntityID = skiff
        world.previousPositionComponents.insert(
            PreviousPositionComponent(position: SIMD3<Double>(100, 100, 0)),
            for: skiff
        )
        world.positionComponents.insert(PositionComponent(position: SIMD3<Double>(103, 96, 0)), for: skiff)

        var system = CameraFollowSystem()
        system.update(world: &world, deltaTime: 1.0 / 60)

        #expect(world.camera.position == SIMD3<Float>(13, 16, 500))
        #expect(world.camera.rotation.vector == rotation.vector)
        #expect(world.camera.projection == projection)
    }
}
