import simd
import Testing
@testable import Engine2

@MainActor
struct ScreenViewpointControllerTests {
    @Test func passesThroughTheExactLatestDefaultUntilOverridden() {
        let id = RenderViewpointID()
        let controller = ScreenViewpointController(id: id)
        let firstDefault = Camera(position: SIMD3<Float>(1, 2, 8))
        let secondDefault = Camera(position: SIMD3<Float>(4, 5, 9))

        let first = controller.resolveViewpoint(defaultCamera: firstDefault)
        let second = controller.resolveViewpoint(defaultCamera: secondDefault)

        #expect(first.id == id)
        #expect(first.revision == .zero)
        #expect(first.camera == firstDefault)
        #expect(second.id == id)
        #expect(second.revision == .zero)
        #expect(second.camera == secondDefault)
    }

    @Test func dragSeedsFromLatestDefaultAndPreservesProjectionAndVerticalOffset() {
        let target = SIMD3<Float>(0, 1, 0)
        let projection = Camera.Projection.orthographic(
            height: 12,
            near: 0.5,
            far: 200
        )
        let defaultCamera = Camera.lookingAt(
            target,
            from: SIMD3<Float>(0, 4, 8),
            projection: projection
        )
        let controller = ScreenViewpointController(
            target: target,
            pointerOrbitSensitivity: 1
        )

        controller.receive(
            .mouseDragged(
                delta: SIMD2<Float>(.pi / 2, 99),
                position: .zero
            ),
            defaultCamera: defaultCamera
        )

        let viewpoint = controller.resolveViewpoint(defaultCamera: Camera())
        #expect(viewpoint.revision.rawValue == 1)
        #expect(viewpoint.camera.position.isApproximately(SIMD3<Float>(8, 4, 0)))
        #expect(viewpoint.camera.projection == projection)

        let targetInViewSpace = viewpoint.camera.viewMatrix * SIMD4<Float>(target, 1)
        #expect(targetInViewSpace.x.isApproximately(0))
        #expect(targetInViewSpace.y.isApproximately(0))
        #expect(targetInViewSpace.z < 0)
    }

    @Test func scrollZoomsAndDoesNotReviseWhenAlreadyStoppedByAClamp() {
        let defaultCamera = Camera.lookingAt(.zero, from: SIMD3<Float>(0, 0, 8))
        let controller = ScreenViewpointController(
            scrollZoomSensitivity: 1,
            minimumRadius: 4,
            maximumRadius: 10
        )

        controller.receive(
            .scroll(delta: SIMD2<Float>(0, 20)),
            defaultCamera: defaultCamera
        )
        #expect(controller.revision.rawValue == 1)
        #expect(controller.resolveViewpoint(defaultCamera: defaultCamera).camera.position
            .isApproximately(SIMD3<Float>(0, 0, 4)))

        controller.receive(
            .scroll(delta: SIMD2<Float>(0, 20)),
            defaultCamera: defaultCamera
        )
        #expect(controller.revision.rawValue == 1)

        controller.receive(
            .scroll(delta: SIMD2<Float>(0, -20)),
            defaultCamera: defaultCamera
        )
        #expect(controller.revision.rawValue == 2)
        #expect(controller.resolveViewpoint(defaultCamera: defaultCamera).camera.position
            .isApproximately(SIMD3<Float>(0, 0, 10)))
    }

    @Test func unrelatedAndZeroEventsDoNotCreateAnOverride() {
        let defaultCamera = Camera(position: SIMD3<Float>(2, 3, 9))
        let controller = ScreenViewpointController()

        controller.receive(
            .keyDown(KeyboardKey(keyCode: 49, displayName: "Space")),
            defaultCamera: defaultCamera
        )
        controller.receive(
            .mouseDragged(delta: .zero, position: .zero),
            defaultCamera: defaultCamera
        )
        controller.receive(
            .mouseDragged(delta: SIMD2<Float>(0, 4), position: .zero),
            defaultCamera: defaultCamera
        )
        controller.receive(.scroll(delta: .zero), defaultCamera: defaultCamera)

        let viewpoint = controller.resolveViewpoint(defaultCamera: defaultCamera)
        #expect(viewpoint.revision == .zero)
        #expect(viewpoint.camera == defaultCamera)
    }

    @Test func resetClearsOnlyARealOverride() {
        let defaultCamera = Camera.lookingAt(.zero, from: SIMD3<Float>(0, 0, 8))
        let laterDefault = Camera(position: SIMD3<Float>(1, 2, 9))
        let controller = ScreenViewpointController(pointerOrbitSensitivity: 1)

        controller.reset()
        #expect(controller.revision == .zero)

        controller.receive(
            .mouseDragged(delta: SIMD2<Float>(0.5, 0), position: .zero),
            defaultCamera: defaultCamera
        )
        #expect(controller.revision.rawValue == 1)

        controller.reset()
        #expect(controller.revision.rawValue == 2)
        #expect(controller.resolveViewpoint(defaultCamera: laterDefault).camera == laterDefault)

        controller.reset()
        #expect(controller.revision.rawValue == 2)
    }

    @Test func canBeConsumedThroughTheViewpointSourceBoundary() {
        let controller = ScreenViewpointController()
        let source: any PRenderViewpointSource = controller
        let defaultCamera = Camera(position: SIMD3<Float>(0, 1, 7))

        #expect(source.resolveViewpoint(defaultCamera: defaultCamera).camera == defaultCamera)
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
