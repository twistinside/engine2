import Testing
@testable import Engine2

struct OffscreenRenderRejectionTests {
    @Test func classifiesSelectedCameraFailureAsAnInvalidViewpoint() {
        #expect(OffscreenRenderRejection(.invalidSelectedCamera) == .invalidViewpoint)
    }

    @Test(
        arguments: [
            RenderFrameProjectionError.missingPosition(
                entityID: EntityID(index: 1, generation: 2)
            ),
            .unsupportedNormalTransform(
                entityID: EntityID(index: 3, generation: 4)
            ),
            .nonfiniteModelViewTransform(
                entityID: EntityID(index: 5, generation: 6)
            ),
            .nonfiniteModelViewProjectionTransform(
                entityID: EntityID(index: 7, generation: 8)
            )
        ]
    )
    func classifiesEntityFailuresAsInvalidPresentation(
        _ projectionError: RenderFrameProjectionError
    ) {
        #expect(OffscreenRenderRejection(projectionError) == .invalidPresentation(projectionError))
    }
}
