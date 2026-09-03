import Testing
import simd
@testable import Engine2

struct CameraFollowSystemTests {
    @Test func translatesCameraByTargetDisplacementWithoutChangingViewPolicy() {
        var world = World()
        let skiff = EntityID(index: 0, generation: 0)
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
