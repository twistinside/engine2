import Testing
@testable import Engine2

struct RenderViewpointTests {
    @Test func equalityIncludesIdentityRevisionAndCamera() {
        let id = RenderViewpointID()
        let camera = Camera(position: .init(1, 2, 3))
        let value = RenderViewpoint(id: id, revision: .zero, camera: camera)

        #expect(value == RenderViewpoint(id: id, revision: .zero, camera: camera))
        #expect(value != RenderViewpoint(
            id: RenderViewpointID(),
            revision: .zero,
            camera: camera
        ))
        #expect(value != RenderViewpoint(
            id: id,
            revision: .zero.advanced(),
            camera: camera
        ))
        #expect(value != RenderViewpoint(
            id: id,
            revision: .zero,
            camera: Camera(position: .init(3, 2, 1))
        ))
    }
}
