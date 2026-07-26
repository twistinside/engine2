import Testing
@testable import Engine2

struct RenderViewpointTests {
    @Test func equalityIncludesIdentityRevisionAndCamera() {
        let id = RenderViewpointID()
        let cameraPosition = SIMD3<Float>(1, 2, 3)
        let camera = Camera(
            position: cameraPosition,
            rotation: Transform.identityRotation,
            projection: .standardPerspective
        )
        let value = RenderViewpoint(id: id, revision: .zero, camera: camera)
        let equalValue = RenderViewpoint(
            id: id,
            revision: .zero,
            camera: camera
        )
        let differentID = RenderViewpointID()
        let differentIdentityValue = RenderViewpoint(
            id: differentID,
            revision: .zero,
            camera: camera
        )
        let differentRevisionValue = RenderViewpoint(
            id: id,
            revision: .zero.advanced(),
            camera: camera
        )
        let differentCameraPosition = SIMD3<Float>(3, 2, 1)
        let differentCamera = Camera(
            position: differentCameraPosition,
            rotation: Transform.identityRotation,
            projection: .standardPerspective
        )
        let differentCameraValue = RenderViewpoint(
            id: id,
            revision: .zero,
            camera: differentCamera
        )

        #expect(value == equalValue)
        #expect(value != differentIdentityValue)
        #expect(value != differentRevisionValue)
        #expect(value != differentCameraValue)
    }
}
